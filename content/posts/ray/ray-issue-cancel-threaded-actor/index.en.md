---
title: "Add support for cancelling threaded actor task"
summary: "Issue deep dive on how to support cancellation for threaded actor task"
date: 2025-12-27T20:09:42+08:00
description: ""
slug: "ray-cancel-threaded-actor"
tags: ["Ray"]
series: ["Ray Issues"]
series_order: 1
cascade:
  showSummary: true
  hideFeatureImage: false
draft: false
---


> - Issue link: https://github.com/ray-project/ray/issues/58213
> - My PR: https://github.com/ray-project/ray/pull/58914


## Issue Description

Originally, cancelling threaded actor task is not supported. This issue is requesting adding the support for cancel threaded actor with an `is_canceled` flag to detect the cancellation. 

We are expecting the usage like so:

```python
@ray.remote
class SyncActor:
    def __init__(self):
        self.is_canceled = False

    def long_running_method(self):
        """A sync actor method that checks for cancellation periodically."""
        for i in range(100):
            # For sync actor tasks, is_canceled() can be checked in the task body
            if ray.get_runtime_context().is_canceled():
                self.is_canceled = True
                print("Actor task canceled, cleaning up...")
                return "canceled"
            time.sleep(0.1)
        return "completed"
```

## How to cancel actor

Actor is a stateful worker that keeps the state. When calling actor method, it can access and mutate the worker's state. While it's stateful, it's not safe for us to directly interrupt it like what we did for normal task, as we will lose the current state. The better way is to enable the graceful termination option so that we can clean up before termination, like what we have for async actor.


For async actor, it's running in the `asyncio.Task`, where `asyncio` is the standard Python library ([link](https://docs.python.org/3/library/asyncio-task.html)). When canceling the async actor, Ray will cancel the `asyncio.Task`, which will raise an `asyncio.CancelledError`. The official document recommends us to use `try/finally` block to do the clean up even if we cancel the task ([link](https://docs.python.org/3/library/asyncio-task.html#task-cancellation))


Here’s the example of how to start and cancel an actor. We use async actor as example here:


```python
import ray
import asyncio
import time


@ray.remote
class Actor:
    async def f(self):
        try:
            await asyncio.sleep(5)
        except asyncio.CancelledError:
            print("Actor task canceled.")


actor = Actor.remote()
ref = actor.f.remote()

# Wait until task is scheduled.
time.sleep(1)
# Cancel the actor with ray.cancel
ray.cancel(ref)

# When doing ray.get on the canceled object, the TaskCancelledError will be raised
try:
    ray.get(ref)
except ray.exceptions.TaskCancelledError:
    print("Object reference was cancelled.")
```



Below is the brief code path on calling the `ray.cancel()`. Note that the place we call `ray.cancel()` is in the “Submitter” node, and this will be send to the “Executor” node through RPC.

- **Submitter side**
   - `ray.cancel(ref)` 
   - → `worker.core_worker.cancel_task()` (`python/ray/_private/worker.py`)
   - → `CCoreWorkerProcess.GetCoreWorker().CancelTask` (`python/ray/_raylet.pyx`)
   - → `CoreWorker::CancelTask` (`src/ray/core_worker/core_worker.cc`) 
   - → `ActorTaskSubmitter::CancelTask(task_spec, recursive)`
      - If the task is in the actor’s submitter queue, can be canceled directly; otherwise send RPC: `client->CancelTask`
- **Threaded actor task - Executor side**
   - `CoreWorker::HandleCancelTask()` 
   - → `CancelActorTaskOnExecutor()`
   - → `TaskReceiver::CancelQueuedActorTask()`
   - → If queued, remove from queue
   - → If running, cannot cancel (return success to avoid retry)
- **Async actor task - Executor side**
   - `CoreWorker::HandleCancelTask()`
   - → `CancelActorTaskOnExecutor()`
   - → `task_execution_service_.post()` (into the actor event loop)
   - If running: `cancel_async_actor_task()` → `fut.cancel()` → Python async task receives `asyncio.CancelledError`
   - If queued: `TaskReceiver::CancelQueuedActorTask()`



Originally, when the threaded actor is running, Ray will ignore the cancel signal and keep running the actor. This is what we want to solve in this issue. My solution is described in the next section.



## My Solution

To tackle this, we need following components:

1. Python API `ray.get_runtime_context().is_canceled()` to show that the actor is canceled

2. Record the cancellation state

3. Raise `TaskCanceled` error when `ray.get()` on the cancelled task



### Python API

I started from the Python API to know where the cancellation state will be read from. The `is_canceled` API that users will use is defined in `python/ray/runtime_context.py` ([code](https://github.com/ray-project/ray/pull/58914/files#diff-11a5cb3df7de6bd727b13f62d853a360d8fb64ad5f41591c0eb0721715eaaed6R553))



```python
def is_canceled(self) -> bool:
  ...
  return self.worker.is_canceled
```

Here, calling `is_canceled` from the `self.worker` will follow the code path ([1](https://github.com/ray-project/ray/pull/58914/files#diff-bec668cc316d34704cdc3e37dd4ce18e4e87764fdf2c28b1504478c7eb8291deR639) → [2](https://github.com/ray-project/ray/pull/58914/files#diff-31e8159767361e4bc259b6d9883d9c0d5e5db780fcea4a52ead4ee3ee4a59a78R3760) → [3](https://github.com/ray-project/ray/pull/58914/files#diff-52339e7cd2a22cd1c21b1973ba599995827a4b12fdc42fd06c5709836acd767eR2498)) and eventually goes into `CoreWorker::IsTaskCanceled`. This is the place that we will check the task cancellation status. 



### Record the cancellation state

The cancel state can be put in either Python side or Cpp side, which is better? 

My first proposal is to add a task context class on the Python side to record the task cancellation state (see [here](https://app.heptabase.com/cca76f49-6aa3-49b9-978f-6685a97bb309/card/9e482551-1ae0-49c9-8e57-599376154b1a)). However, this introduces a thread-safety issue: when multiple threads (e.g., one executing a callback and another running the actual actor task) access the shared cancellation flag simultaneously, a race condition can occur. To ensure thread safety and better performance, we should store the cancellation state in C++, utilizing C++ mutex or atomic variables (see [here](https://github.com/ray-project/ray/issues/58213#issuecomment-3560455261)).

There are also different places that we can add `is_canceled` flag in C++ part:

1. Directly use `is_canceled_` flag in `TaskManager`.
   - this cannot work as `TaskManager` runs in submitter side, and we want to get the is canceled status in the executor side

2. Put in `WorkerThreadContext`(`worker_context_`) in `HandleCancelTask` ([c](https://github.com/machichima/ray/blob/83a9842eedb56d82fad1269b1cb5aaa433c1b227/src/ray/core_worker/core_worker.cc#L3938-L3938)[ode](https://github.com/ray-project/ray/blob/83a9842eedb56d82fad1269b1cb5aaa433c1b227/src/ray/core_worker/core_worker.cc#L3938-L3938))
   - This cannot work either. In executor, the place receiving RPC request and executing the task are in separate thread
      - Execute task (main thread): [c](https://github.com/machichima/ray/blob/83a9842eedb56d82fad1269b1cb5aaa433c1b227/src/ray/rpc/grpc_server.cc#L171-L171)[ode](https://github.com/ray-project/ray/blob/83a9842eedb56d82fad1269b1cb5aaa433c1b227/src/ray/rpc/grpc_server.cc#L171-L171)
      - RPC request (spawned new thread): [code](https://github.com/ray-project/ray/blob/83a9842eedb56d82fad1269b1cb5aaa433c1b227/src/ray/rpc/grpc_server.cc#L171-L171)

3. Record the canceled task ID in the `canceled_tasks_` hash set that's shared between threads in the executor ([code](https://github.com/ray-project/ray/pull/58914/files#diff-d6c03a895589a1c58e581dc22845b1f2b0290379bf183af904dd6170e41e2706R1854)).
   - This is what we eventually do. When calling  `CoreWorker::CancelTaskOnExecutor`, we will put the task ID into the set ([code](https://app.heptabase.com/cca76f49-6aa3-49b9-978f-6685a97bb309/card/9e482551-1ae0-49c9-8e57-599376154b1a))
   - When calling `CoreWorker::IsTaskCanceled`, we will check if the task ID is present in the `canceled_tasks_` set ([code](https://github.com/ray-project/ray/pull/58914/files#diff-52339e7cd2a22cd1c21b1973ba599995827a4b12fdc42fd06c5709836acd767eR2502))


### Raise `TaskCanceled` error

When async actor is canceled, it will raise `asyncio.CancelledError`, which is treated as an application error. In this case, when calling `CompletePendingTask`, it will raise `TASK_CANCELLED` error if it receives `is_application_error` to be true.


However, when cancelling threaded actor, we will not raise any error, so the `is_application_error` will be false. In this case, we need to manually fail the actor task and raise the `TASK_CANCELLED` (as mentioned [here](https://github.com/ray-project/ray/pull/58914/files)).


See further information here: https://github.com/ray-project/ray/pull/58914/files#r2564220449


## Summary

This is my first Ray PR working on a feature and digging into the C++ side. It has been a pretty exciting experience, and I plan to keep contributing to Ray with more cool PRs ahead!

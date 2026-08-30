---
title: "Review code with Neovim"
summary: "My Neovim code review setup: worktrunk, tmux sessions, Diffview.nvim and codecompanion.nvim"
date: 2026-08-06T21:19:42+08:00
description: "A complete Neovim code review setup: worktrunk, tmux sessions, Diffview.nvim and codecompanion.nvim"
slug: ""
tags: ["Tools"]
series: ["Neovim"]
series_order: 1
cascade:
  showSummary: true
  hideFeatureImage: false
draft: false
---

As a long-time Neovim user, I've always been looking for the most convenient way to review code in Neovim.
After all, a Neovim setup you configured yourself is just too comfortable to leave. This post shares how I
do it today, and hopefully gets more people to join the Neovim side!

My current setup:
- Wezterm with tmux
- Neovim (review with the codecompanion plugin)
- [worktrunk](https://github.com/max-sixty/worktrunk): worktree CLI


## How I got here

My current workflow is inspired by [orca](https://github.com/stablyai/orca), an ADE (Agent Development Environment). There are a few features I
really like:

1. Open multiple worktrees quickly

The most useful thing in orca for me is how fast you can open and manage multiple worktrees: paste a PR link
and it creates a git worktree and opens it as its own workspace. A workspace is a lot like a terminal session:
you can open terminal tabs / claude tabs, and split windows. This is a big help for maintainers who review many
PRs, since you can have several open at the same time, running in parallel, and switch between them freely.

{{< figure
    src="img/orca-create-worktree.png"
    alt="orca-create-worktree"
    caption="Paste a PR link and orca creates a worktree and opens it as its own workspace"
    class="mx-auto max-w-md"
>}}

2. View the PR diff

This is just the diff between the current branch and main / master. With it you don't need to bounce back and
forth to GitHub to read the diff, you can do it all in one window.


{{< figure
    src="img/orca-pr-diff.png"
    alt="orca-pr-diff"
    caption="Orca's PR diff page: diff on the left, changed files on the right"
>}}


3. Leave comments for AI on the diff page

You can open the diff page and leave comments with questions for the AI, then send them one at a time to the
current AI chat / a new chat, or send all comments at once.


{{< figure
    src="img/diff-add-note.png"
    alt="diff-add-note"
    caption="Leave comments directly on the diff, then send them to the AI one by one or all at once"
    class="mx-auto max-w-2xl"
>}}


Of course orca still has some gaps: there seems to be no editor support yet, so no go to definition (I saw
issues on GitHub asking for vscode support and so on). Right now I open a terminal tab with nvim and review
alongside with diffview, then jump to the matching orca diff when I need to ask the AI (a bit annoying).


## My current setup

Here's how my setup gets the three orca features above:

### 1. Open Multiple Worktrees Quickly

This is done with [worktrunk](https://github.com/max-sixty/worktrunk). Usage is very simple. Say I want to
switch to the branch of PR 1234 to review it:

```sh
wt switch pr:1234
```

It pulls the PR, creates a worktree, and switches to it. When the review is done, `wt remove` in the same
folder removes the worktree. `wt list` shows all current worktrees:


{{< figure
    src="img/wt-list.png"
    alt="wt-list"
    caption="`wt list` shows all current worktrees"
>}}

Worktrunk only solves switching worktrees quickly. So how do you open several worktrees at the same time?
That's where tmux sessions come in. I won't go into tmux sessions in detail; think of them as multiple
terminal workspaces, each with its own tabs. For me, reviewing several PRs while also writing code, this is
extremely useful.

In tmux I have a shortcut `<leader> + N` to quickly create a new session:

```conf
bind-key N command-prompt -p "new session:" "new-session -s '%%'"
```


And `<leader> + s` opens the sessions list:

```conf
bind-key s choose-tree -Zs -O name
```


### 2. View the PR diff in Nvim

I think this is a really practical feature for reviewers: quickly read the diff and jump to files. In nvim I
use [Diffview.nvim](https://github.com/sindrets/diffview.nvim), which can:
1. Show the diff of local changes
2. Show the diff between two commits
3. Handle merge conflicts (it has a JetBrains-style three-way view, which I think is great)
4. Show the commit history and diff of a single file

To view a PR diff we use point 2 above, but copying the current commit and pasting it into the command every
time takes too long, so I added a keymap `<leader> + gd`
([config](https://github.com/machichima/nary-dotfile/blob/5796e42391baa89cacb8c96d66197cb02b329e44/nvim/.config/nvim/lua/plugins/diffview.lua#L7-L18))
to open the PR diff quickly.


{{< video
    src="img/nvim-diff-pr.mp4"
    caption="Viewing a PR diff with Diffview.nvim"
    controls=true
    muted=true
>}}

Note: the color theme that fits this plugin best is tokyonight. See this discussion for how to set it up
([issue comment](https://github.com/sindrets/diffview.nvim/issues/546)), or take a look at my
[config](https://github.com/machichima/nary-dotfile/blob/5796e42391baa89cacb8c96d66197cb02b329e44/nvim/.config/nvim/lua/plugins/diffview.lua#L23-L37).

### 3. Using AI in Nvim

This part isn't limited to "leave comments for AI on the diff page" above. It's about how I use AI in nvim in
general (leaving comments is covered too 😄).

The tool I use is [codecompanion.nvim](https://github.com/olimorris/codecompanion.nvim). It toggles a vertical
split window in nvim as the place to talk to the AI. That window is actually just a markdown file, so you can
use vim motions in it. To make it easy to select a region and ask the AI about it, I added a `<leader> + cs`
keymap in my 
[config](https://github.com/machichima/nary-dotfile/blob/3e6f995e4369d647109a523e6f639fba9249d8b8/nvim/.config/nvim/lua/plugins/codecompanion.lua#L159-L197).
It sends the selected lines to the code companion chat as `@filename:line_number`, which makes the whole flow
much smoother.

{{< video
    src="img/nvim-cc-basic.mp4"
    caption="Basic code companion usage"
    controls=true
    muted=true
>}}


On top of that, code companion recently added a code review feature, which works really well together with
Diffview.nvim. Diffview already takes two windows side by side, so opening another AI chat window gets
crowded. Instead, we can use the code review feature to leave comments, then send them all at once to ask the
AI or have it make the changes.



{{< video
    src="img/nvim-diff-comment.mp4"
    caption="Using code review comments in diff view"
    controls=true
    muted=true
>}}


If the side window feels too small, you can move it to a new tab with nvim's built-in `Ctrl-w + T`. It's still the same buffer, so the content stays in sync.



{{< video
    src="img/nvim-cc-new-tab.mp4"
    caption="Opening the AI chat in a new tab"
    controls=true
    muted=true
>}}


I have a few more code companion settings, like listing all comments in the quickfix list. See my
[config](https://github.com/machichima/nary-dotfile/blob/5796e42391baa89cacb8c96d66197cb02b329e44/nvim/.config/nvim/lua/plugins/codecompanion.lua)
for more settings.


## Wrapping up

That's a quick tour. Feel free to check out my
[nvim](https://github.com/machichima/nary-dotfile/tree/main/nvim/.config/nvim) and
[tmux](https://github.com/machichima/nary-dotfile/blob/main/tmux/.config/tmux/tmux.conf) configs.

btw, the latest code companion [release](https://github.com/olimorris/codecompanion.nvim/releases/tag/v19.23.0)
adds [herdr](https://github.com/herdrdev/herdr) support. Maybe I'll switch over and give it a try 😄

---
title: "用 Neovim review code"
summary: "分享我用 Neovim review code 的 workflow: worktrunk、tmux sessions、Diffview.nvim 和 codecompanion.nvim"
date: 2026-08-06T21:19:42+08:00
description: "用 Neovim review code 的完整配置: worktrunk、tmux sessions、Diffview.nvim 和 codecompanion.nvim"
slug: ""
tags: ["Tools"]
series: ["Neovim"]
series_order: 1
cascade:
  showSummary: true
  hideFeatureImage: false
draft: false
---

身為用 Neovim 多年的使用者, 我一直在找有沒有最方便用 Neovim review code 的方式, 畢竟自己配置的 Neovim
用得真的太順手了。這篇文章的目的是把我現在的使用方式分享給大家, 希望有更多人加入 Neovim 的行列！

我目前的配置是:
- Wezterm with tmux
- Neovim (用 codecompanion 插件 review)
- [worktrunk](https://github.com/max-sixty/worktrunk): worktree CLI


## 配置歷程

我現在的 workflow 是受 [orca](https://github.com/stablyai/orca) 的啟發, 他是個 ADE (Agent Development Environment), 有以下幾個功能是我非常喜歡的:

1. 快速開多個 worktrees

orca 中我覺得非常實用的功能就是可以快速的打開並管理多個 worktree: 只要貼上 PR link, 他就會自己 create 一個
git worktree 並開成獨立的 workspace。一個 workspace 就很像一個 terminal session, 可以開 terminal tabs / claude
tabs, 也可以 split window。這對於要 review 多個 PRs 的 maintainer 來說非常有幫助, 可以同時開好幾個 PR 並行跑,
還可以快速接換。

{{< figure
    src="img/orca-create-worktree.png"
    alt="orca-create-worktree"
    caption="貼上 PR link 就會自動 create worktree 並開成獨立 workspace"
    class="mx-auto max-w-md"
>}}

2. 看 PR 的 diff

其實就是看現在這個 branch 跟 main / master 之間的 diff。有這個功能我們就不用來回切換 github 來看 diff,
直接在一個視窗看就好。


{{< figure
    src="img/orca-pr-diff.png"
    alt="orca-pr-diff"
    caption="Orca 的 PR diff 頁面: 左邊 diff, 右邊是變更的檔案列表"
>}}


3. 在 diff page 上面留 comments for AI

我們可以直接打開 diff 頁面, 並留下一些要問 AI 的 comments, 之後可以單個送出到當前的 AI chat / new chat,
或是全部 comments 一起送出。


{{< figure
    src="img/diff-add-note.png"
    alt="diff-add-note"
    caption="在 diff 上直接留 comment, 之後可單個或全部送給 AI"
    class="mx-auto max-w-2xl"
>}}


當然 orca 還是有些不足的地方: 現在好像沒有 editor 支援, 沒辦法 go to definition (github 上看到有 support vscode 之類的 issues).
我現在是開一個 terminal tab & 開 nvim -> 用 diffview 同步 review, 需要問 AI 的再跑到對應的 orca diff 中問
(有點麻煩)。


## 現在的配置

以下講一下我的配置怎麼做到上面說的三個 orca 的功能:

### 1. 快速開多個 worktrees

這個是用 [worktrunk](https://github.com/max-sixty/worktrunk) 實現的, 他的用法非常簡單, 假設我要切換到 PR 1234
的 branch 上面 review 的話, 我就用:

```sh
wt switch pr:1234
```

他就會自動 pull PR + create worktree + 切換到那個 worktree, review 完要把 worktree remove
掉只要在同一個資料夾下面 `wt remove` 就行, 非常方便。同時也可以用 `wt list` 看現在所有的 worktrees:


{{< figure
    src="img/wt-list.png"
    alt="wt-list"
    caption="`wt list` 列出目前所有的 worktrees"
>}}

上面 worktrunk 只解決快速切換 worktree, 那要怎麼一次同時開多個 worktree 呢? 這是後就要用 tmux 的 sessions!
tmux sessions 功能我就不詳細介紹了, 你可以想成開好幾個 terminal workspaces, 每個 workspace 有自己的
tabs。對同時需要 review 多個 PRs 並同時寫 code 的我來說非常有用。

我 tmux 裡面有設定快捷鍵 `<leader> + N` 可以快速的新建 session:

```conf
bind-key N command-prompt -p "new session:" "new-session -s '%%'"
```


然後 `<leader> + s` 會打開 sessions list:

```conf
bind-key s choose-tree -Zs -O name
```


### 2. Nvim 裡面看 PR 的 diff

這我覺得對 reviewer 來說是個非常實用的功能, 可以快速的看 diff 並跳到檔案。在 nvim 裡面, 我是用
[Diffview.nvim](https://github.com/sindrets/diffview.nvim), 他可以做到:
1. 看本地改動的 diff
2. 看兩個 commit 間的 diff
3. 處理 merge conflicts (有像 JetBrain 的三行式我覺得很讚)
4. 看一個檔案的 history commits 跟 diff

我們要看一個 PR 的 diff 用的就是上面提到的第 2 點, 但每次還要先複製現在的 commit 然後再貼到指令上太花時間的,
所以我加一個 keymap `<leader> + gd` ([config](https://github.com/machichima/nary-dotfile/blob/5796e42391baa89cacb8c96d66197cb02b329e44/nvim/.config/nvim/lua/plugins/diffview.lua#L7-L18)) 可以快速的打開 PR diff。


{{< video
    src="img/nvim-diff-pr.mp4"
    caption="Diffview.nvim 看 PR diff"
    controls=true
    muted=true
>}}

Note: 這個 plugin 最適配的 color theme 是 tokyonight, 可以看一下這邊的討論去配置: ([issue comment](https://github.com/sindrets/diffview.nvim/issues/546)), 
也可以看一下我的 [config](https://github.com/machichima/nary-dotfile/blob/5796e42391baa89cacb8c96d66197cb02b329e44/nvim/.config/nvim/lua/plugins/diffview.lua#L23-L37)。

### 3. Nvim 裡面使用 AI

這部分不局限於上面說的 "在 diff page 上面留 comments for AI", 而是我怎麼在 nvim 裡面使用 AI 的 (當然留 comment
也會 cover 到 😄)。

我用的工具是 [codecompanion.nvim](https://github.com/olimorris/codecompanion.nvim), 他可以在 nvim 裡面去
toggle 一個 virtical split window 當作跟 AI 溝通的窗口。這個窗口其實就是個 markdown file, 所以我們可以在上面用
vim 操作。為了方便選取一個區域來問 AI, 我在 config 裡面加了一個 `<leader> + cs` ([config](https://github.com/machichima/nary-dotfile/blob/3e6f995e4369d647109a523e6f639fba9249d8b8/nvim/.config/nvim/lua/plugins/codecompanion.lua#L159-L197))
的 keymap, 會把我選擇的段落以 `@filename:line_number` 的格式傳到 code companion 對話框裡面, 讓整個操作更絲滑。

{{< video
    src="img/nvim-cc-basic.mp4"
    caption="code companion 簡易操作"
    controls=true
    muted=true
>}}


除了上面說的功能外, code companion 在最近加入了 code review 的功能, 這個功能跟 Diffview.nvim
一起用非常方便。因為 diff view 一次會有左右兩個視窗, 再開一個 AI chat 的窗口就會比較擁擠, 這時候我們就可以用
code review 功能留下一些 comments, 再一次送出問。 這時候我們就可以用 code review 功能留下一些 comments,
一次送出問 AI 或請 AI 改。



{{< video
    src="img/nvim-diff-comment.mp4"
    caption="在 diff view 用 code review comment"
    controls=true
    muted=true
>}}


如果覺得側邊小視窗太小的話, 也可以把它移動到一個新的 tab 上面, 用的是 nvim 內建的 `Ctrl-w + T`。當然他們是同一個 buffer, 所以彼此的內容是連動的。



{{< video
    src="img/nvim-cc-new-tab.mp4"
    caption="在新的 tab 打開 AI chat"
    controls=true
    muted=true
>}}


Code companion 我還有一些其他設定, 像是在 quick fix 中 list 所有的 comments 等等, 可以參考我的 [config](https://github.com/machichima/nary-dotfile/blob/5796e42391baa89cacb8c96d66197cb02b329e44/nvim/.config/nvim/lua/plugins/codecompanion.lua)。


## 結尾

這就是一些粗淺的介紹, 歡迎參考我的
[nvim](https://github.com/machichima/nary-dotfile/tree/main/nvim/.config/nvim) 跟
[tmux](https://github.com/machichima/nary-dotfile/blob/main/tmux/.config/tmux/tmux.conf) 配置。

btw code companion 最新的 [release](https://github.com/olimorris/codecompanion.nvim/releases/tag/v19.23.0) 有
[herdr](https://github.com/herdrdev/herdr) support, 說不定我會跳槽過去用看看 😄

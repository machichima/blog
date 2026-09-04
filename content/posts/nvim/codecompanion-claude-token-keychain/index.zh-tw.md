---
title: "codecompanion 把 token 放 Keychain 裡面"
summary: "把 CLAUDE_CODE_OAUTH_TOKEN export 在 zshrc 會讓 Claude Code CLI 用 Fable 時說只能用 usage credit, 每開新 terminal 都要重新登入, 記錄怎麼改讓 codecompanion 從 macOS Keychain 讀自己的 token"
date: 2026-08-31T12:00:00+08:00
description: "CLAUDE_CODE_OAUTH_TOKEN 放 zshrc 導致 Claude Code CLI 用 Fable 時只能用 usage credit, 要一直重新登入的原因與解法"
slug: ""
tags: ["Tools"]
series: ["Neovim"]
series_order: 2
cascade:
  showSummary: true
  hideFeatureImage: false
draft: false
---

我最近在 Claude Code CLI 用 Fable 模型的時候他都會說我只能用 usage credit, 每次開新的 terminal 都需要重新
logout + login 才能修好, 很麻煩。我原本以為是 Claude Code 的 bug, 結果同事說他沒有遇到這個情況, 於是我開始懷疑是自己的
setup 的問題。最後發現罪魁禍首是我在 `.zshrc` 裡面 `export CLAUDE_CODE_OAUTH_TOKEN`, 這個 token 是給
[codecompanion.nvim](https://github.com/olimorris/codecompanion.nvim) 的 `claude_code` adapter 用的,
但放在全域環境裡面 CLI 會優先讀這個, 導致上面說的 bug。這邊紀錄一下原因跟解法。

## 問題

`CLAUDE_CODE_OAUTH_TOKEN` 環境變數的優先權**高於** Keychain 裡存的登入憑證, 所以整個流程變成:

1. 在某個 terminal `/login` 成功 -> 新憑證存進 macOS Keychain, 這個 session 沒問題
2. 開新 terminal -> `.zshrc` 重新 export 舊 token -> CLI 直接用環境變數, 忽略 Keychain
3. 舊 token 綁的是舊的授權, 於是又要重新 logout / login...

也就是說只要 `.zshrc` 裡還有那行 export, 你在 CLI 做的登入永遠只對當前 session 有效。

## 解法: 把 token 搬進 Keychain

codecompanion 官方其實有文件說明這個情況: token 應該放在 adapter 的 `env` 設定裡, 而不是 export 到全域 shell ([ACP
adapter 文件](https://codecompanion.olimorris.dev/configuration/adapters-acp))。而且 `env` 的值支援 `cmd:`
前綴, 會透過 shell 執行指令拿值 ([HTTP adapter
文件](https://codecompanion.olimorris.dev/configuration/adapters-http)), 官方範例是用 1Password CLI,
我們可以套到 macOS 內建的 Keychain 上。

### 1. 把 token 存進 Keychain

**不要**把 token 直接打在指令裡 (會留在 shell history), 用 interfactive mode 輸入:

```sh security add-generic-password -a "$USER" -s codecompanion-claude -w ```

他會提示你輸入密碼兩次, 把 token 貼上去就好 (貼上時不會顯示是正常的)。

### 2. 驗證讀得出來

```sh security find-generic-password -w -s codecompanion-claude ```

有印出 token 就 OK。

### 3. 改 codecompanion 設定

把 claude_code adapter 改成從 Keychain 讀:

```lua 
require("codecompanion").setup({
    adapters = {
        acp = {
            claude_code = function()
                return require("codecompanion.adapters").extend("claude_code", {
                    env = {
                        CLAUDE_CODE_OAUTH_TOKEN =
                        "cmd:security find-generic-password -w -s codecompanion-claude | tr -d '\n'",
                    },
                })
            end,
        },
    },
})
```


### 4. 清掉 zshrc 的 export

把 `.zshrc` 裡的 `export CLAUDE_CODE_OAUTH_TOKEN=...` 刪掉, 然後開一個**全新的 terminal** 確認變數已經不在:

```sh echo ${CLAUDE_CODE_OAUTH_TOKEN:+exists}${CLAUDE_CODE_OAUTH_TOKEN:-cleared} ```

顯示 "cleared" 後跑 `claude` 然後 `/login` 登入一次, 之後 所有新 terminal 都不用再 logout / login 了。

## tmux 移除環境變數

如果有用 tmux 的話, 會發現把 `.zshrc` 裡面的 export 清掉後 `CLAUDE_CODE_OAUTH_TOKEN` 還在。這是因為 tmux
server 是常駐 process, 他是很久以前從一個當時還有 export 的 shell 啟動的, 環境變數不會因為你改 `.zshrc`
而更新。之後在 tmux 裡開的每個新 window / pane 的 shell 都是從 server fork 出來的, 全部繼承到舊 token, 即使新
shell 有重新 source 乾淨的 `.zshrc` 也沒用, 因為 source 只會加變數, 不會清掉已繼承的。

我們可以叫 tmux 以後開新的 pane 都移除這個變數, 這樣就不用砍掉現有的 sessions:

```sh tmux set-environment -g -r CLAUDE_CODE_OAUTH_TOKEN ```

已經開著的 pane 各自跑一次:

```sh unset CLAUDE_CODE_OAUTH_TOKEN ```

然後開個新 tmux window 再驗證一次就完成了。當然 `tmux kill-server` 也可以, 但會關掉所有 sessions。

## 結尾

這篇文章說明怎麼讓 codecompanion 從 Keychain 讀自己的 token, 這樣就不用在 `.zshrc` 裡面去 export 環境變數了。

參考資料:
- https://notes.billmill.org/computer_usage/vim/codecompanion.html

---
title: "Put codecompanion's token in Keychain"
summary: "Exporting CLAUDE_CODE_OAUTH_TOKEN in zshrc makes Claude Code CLI say you can only use usage credit with Fable and forces a re-login in every new terminal. Here's how to let codecompanion read its own token from macOS Keychain instead"
date: 2026-08-31T12:00:00+08:00
description: "Why CLAUDE_CODE_OAUTH_TOKEN in zshrc makes Claude Code CLI fall back to usage credit with Fable and keeps asking for re-login, and the fix"
slug: ""
tags: ["Tools"]
series: ["Neovim"]
series_order: 2
cascade:
  showSummary: true
  hideFeatureImage: false
draft: false
---

Recently whenever I used the Fable model in Claude Code CLI, it said I could only use usage credit, and I had to logout + login again in every single new terminal to fix it, which was really annoying. I thought it was a Claude Code bug at first, but my coworker said he didn't run into this, so I started to suspect it was my own setup. It turned out the culprit was the `CLAUDE_CODE_OAUTH_TOKEN` I exported in `.zshrc`. That token is for [codecompanion.nvim](https://github.com/olimorris/codecompanion.nvim)'s `claude_code` adapter, but putting it in the global environment makes the CLI pick it up first, causing the bug above. This post documents the cause and the fix.

## The problem

The `CLAUDE_CODE_OAUTH_TOKEN` environment variable takes **precedence** over the login credentials stored in Keychain, so the whole flow becomes:

1. `/login` succeeds in some terminal -> new credentials go into macOS Keychain, this session is fine
2. Open a new terminal -> `.zshrc` re-exports the old token -> the CLI uses the env var and ignores Keychain
3. The old token is tied to the old authorization, so it's logout / login all over again...

In other words, as long as that export line lives in `.zshrc`, any login you do in the CLI only lasts for the current session.

## The fix: move the token into Keychain

codecompanion actually has docs for this case: the token should go into the adapter's `env` config, not a global shell export ([ACP adapter docs](https://codecompanion.olimorris.dev/configuration/adapters-acp)). On top of that, `env` values support a `cmd:` prefix that runs a shell command to fetch the value ([HTTP adapter docs](https://codecompanion.olimorris.dev/configuration/adapters-http)). The official example uses the 1Password CLI, and we can apply the same trick to macOS's built-in Keychain.

### 1. Store the token in Keychain

**Don't** type the token directly into the command (it would end up in shell history). Use interactive mode instead:

```sh
security add-generic-password -a "$USER" -s codecompanion-claude -w
```

It prompts for the password twice, just paste your token (nothing is echoed while pasting, that's normal).

### 2. Verify it reads back

```sh
security find-generic-password -w -s codecompanion-claude
```

If it prints your token, you're good.

### 3. Update codecompanion config

Point the claude_code adapter at Keychain:

```lua
require("codecompanion").setup({
  adapters = {
    acp = {
      claude_code = function()
        return require("codecompanion.adapters").extend("claude_code", {
          env = {
            CLAUDE_CODE_OAUTH_TOKEN = "cmd:security find-generic-password -w -s codecompanion-claude | tr -d '\n'",
          },
        })
      end,
    },
  },
})
```

### 4. Remove the export from zshrc

Delete the `export CLAUDE_CODE_OAUTH_TOKEN=...` line from `.zshrc`, then open a **brand-new terminal** and confirm the variable is gone:

```sh
echo ${CLAUDE_CODE_OAUTH_TOKEN:+exists}${CLAUDE_CODE_OAUTH_TOKEN:-cleared}
```

Once it says "cleared", run `claude` and `/login` once more. After that, you won't need to logout / login in any new terminal anymore.

## Remove the environment variable from tmux

If you use tmux, you'll find `CLAUDE_CODE_OAUTH_TOKEN` is still there after removing the export from `.zshrc`. This is because the tmux server is a long-running process. It was started ages ago from a shell that still had the export, and its environment doesn't update just because you edited `.zshrc`. Every new window / pane you open inside tmux forks its shell from the server, so they all inherit the old token, even though the new shell re-sources a clean `.zshrc`, because sourcing only adds variables, it never clears inherited ones.

We can tell tmux to strip the variable from every pane opened from now on, so there's no need to kill existing sessions:

```sh
tmux set-environment -g -r CLAUDE_CODE_OAUTH_TOKEN
```

In each already-open pane, run:

```sh
unset CLAUDE_CODE_OAUTH_TOKEN
```

Then open a new tmux window and verify again. Of course `tmux kill-server` also works, but that closes all your sessions.

## Wrapping up

This post shows how to let codecompanion read its own token from Keychain, so there's no need to export the environment variable in `.zshrc` anymore.

References:
- https://notes.billmill.org/computer_usage/vim/codecompanion.html

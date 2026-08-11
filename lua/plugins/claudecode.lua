-- Claude Code context bridge.
--
-- This is NOT Claude running inside nvim. Claude stays in its own ghostty
-- window; nvim only runs the little WebSocket server that the CLI connects to,
-- so a keypress here can push "this file, these lines" into that session --
-- the same thing the VS Code extension does when you send a selection.
--
-- Third-party (coder/claudecode.nvim), reimplementing an undocumented protocol
-- from Anthropic's VS Code and JetBrains extensions. There is no official nvim
-- plugin. If a CLI update ever breaks the handshake, nothing else here suffers:
-- delete this file and everything else keeps working.
--
-- Using it, per project:
--
--   1. Open nvim in the project (the server starts on its own, see below).
--   2. In ghostty, from the same directory:  claude --ide
--      Already inside a session? Run /ide instead.
--   3. Select lines in nvim, press <leader>as. They land in Claude's prompt.
--
-- Step 2 matters: the CLI finds nvim by matching its working directory against
-- the lock file in ~/.claude/ide/, so it has to be launched from the project.

return {
  {
    "coder/claudecode.nvim",

    -- Loaded at VeryLazy rather than on first keypress. The plugin writes its
    -- lock file when it loads, and `claude --ide` can only discover a server
    -- that is already listening -- deferring until <leader>as would mean the
    -- first launch of the day never finds nvim.
    event = "VeryLazy",

    -- The README suggests snacks.nvim, but that is only for drawing Claude's
    -- terminal inside nvim, which is exactly what we are not doing.

    opts = {
      terminal = {
        -- "none": run the server and the send-context tools, but never render
        -- anything Claude-related in nvim and never spawn the CLI. Launching
        -- and connecting is ours to do (see the header).
        provider = "none",
      },
    },

    cmd = {
      "ClaudeCodeSend",
      "ClaudeCodeAdd",
      "ClaudeCodeTreeAdd",
      "ClaudeCodeStatus",
      "ClaudeCodeStart",
      "ClaudeCodeStop",
      "ClaudeCodeDiffAccept",
      "ClaudeCodeDiffDeny",
      "ClaudeCodeCloseAllDiffs",
    },

    -- Deliberately absent: <leader>ac / af / ar / am from the README. Those
    -- drive a Claude terminal inside nvim and only warn under provider "none".
    keys = {
      { "<leader>a", nil, desc = "Claude Code" },
      { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send selection to Claude" },
      { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Send this buffer to Claude" },
      -- netrw is the file explorer here (<leader>e), so send-file-under-cursor
      -- is bound in netrw buffers, matching the visual-mode key.
      { "<leader>as", "<cmd>ClaudeCodeTreeAdd<cr>", ft = "netrw", desc = "Send file to Claude" },
      { "<leader>ai", "<cmd>ClaudeCodeStatus<cr>", desc = "Claude connection status" },

      -- When Claude edits a file it opens a native nvim diff for review.
      -- :w accepts as well; these are the explicit versions.
      { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept Claude's diff" },
      { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Reject Claude's diff" },
    },

    init = function()
      -- Confirm the send landed.
      --
      -- With Claude in another window there is otherwise no sign anything
      -- happened -- the prompt that changed is not on screen. This event fires
      -- only when a client is actually connected, so silence after <leader>as
      -- means "no Claude attached", which is the failure worth catching. Check
      -- with <leader>ai.
      --
      -- Lines arrive 0-indexed (Claude's convention), so +1 to report them the
      -- way the file is numbered on screen.
      vim.api.nvim_create_autocmd("User", {
        group = vim.api.nvim_create_augroup("ClaudeCodeSendFeedback", { clear = true }),
        pattern = "ClaudeCodeSendComplete",
        callback = function(ev)
          local d = ev.data or {}
          local where = d.file_path or "?"
          if d.start_line then
            where = string.format("%s:%d-%d", where, d.start_line + 1, (d.end_line or d.start_line) + 1)
          end
          vim.notify("Sent to Claude: " .. where, vim.log.levels.INFO)
        end,
      })
    end,
  },
}

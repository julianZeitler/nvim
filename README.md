# nvim config

## Prerequisites

### tree-sitter CLI

Required for building treesitter parsers:

```sh
npm install -g tree-sitter-cli
```

After installing, open nvim and run:

```
:TSInstall lua python c typescript tsx rust vim vimdoc
```

### Claude Code (optional)

`lua/plugins/claudecode.lua` lets nvim hand file/line context to a Claude Code
session running in a separate terminal. It needs the [CLI](https://docs.anthropic.com/en/docs/claude-code)
on `$PATH`; without it the plugin loads and does nothing. Connect with
`claude --ide` from the project directory, then `<leader>as` on a selection.
See cheatsheet page 7 (`<leader>?`).

## Plugins

Managed by [lazy.nvim](https://github.com/folke/lazy.nvim). Run `:Lazy sync` on first launch.

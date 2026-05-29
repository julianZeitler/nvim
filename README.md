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

## Plugins

Managed by [lazy.nvim](https://github.com/folke/lazy.nvim). Run `:Lazy sync` on first launch.

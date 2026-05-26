return {
  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    opts = {},
  },

  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim", "saghen/blink.cmp" },
    config = function()
      local capabilities = require("blink.cmp").get_lsp_capabilities()

      vim.lsp.config("basedpyright", {
        cmd = { "basedpyright-langserver", "--stdio" },
        filetypes = { "python" },
        root_markers = { "pyrightconfig.json", "pyproject.toml", "setup.py", ".git" },
        capabilities = capabilities,
        settings = {
          basedpyright = {
            analysis = {
              autoSearchPaths = true,
              diagnosticMode = "openFilesOnly",
              useLibraryCodeForTypes = true,
            },
          },
        },
        before_init = function(_, config)
          local venv = (config.root_dir or vim.fn.getcwd()) .. "/.venv/bin/python"
          if vim.fn.filereadable(venv) == 1 then
            config.settings.python = { pythonPath = venv }
          end
        end,
      })

      vim.lsp.config("clangd", {
        cmd = { "clangd" },
        filetypes = { "c", "cpp", "objc", "objcpp" },
        root_markers = { ".clangd", ".clang-tidy", "compile_commands.json", ".git" },
        capabilities = capabilities,
      })

      vim.lsp.config("rust_analyzer", {
        cmd = { "rust-analyzer" },
        filetypes = { "rust" },
        root_markers = { "Cargo.toml", ".git" },
        capabilities = capabilities,
      })

      require("mason-lspconfig").setup({
        ensure_installed = { "basedpyright", "clangd", "rust_analyzer" },
        automatic_enable = { "basedpyright", "clangd", "rust_analyzer" },
      })
    end,
  },
}

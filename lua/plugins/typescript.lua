return {
  {
    "pmizio/typescript-tools.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "neovim/nvim-lspconfig",
    },
    ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
    keys = {
      { "gd", "<cmd>TSToolsGoToSourceDefinition<cr>", ft = "typescript", desc = "Go to source definition" },
      { "gd", "<cmd>TSToolsGoToSourceDefinition<cr>", ft = "typescriptreact", desc = "Go to source definition" },
    },
    opts = {},
  },
}

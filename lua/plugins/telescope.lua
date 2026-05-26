return {
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
      { "<leader>fc", "<cmd>Telescope live_grep<cr>", desc = "Find in contents" },
      { "<leader>fs", "<cmd>Telescope lsp_document_symbols<cr>", desc = "Find symbols" },
    },
    opts = {},
  },
}

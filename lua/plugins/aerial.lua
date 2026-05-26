return {
  {
    "stevearc/aerial.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    keys = {
      { "<leader>o", "<cmd>AerialToggle<cr>", desc = "Toggle symbol outline" },
    },
    opts = {
      on_attach = function(bufnr)
        vim.keymap.set("n", "[[", "<cmd>AerialPrev<cr>", { buffer = bufnr, desc = "Prev symbol" })
        vim.keymap.set("n", "]]", "<cmd>AerialNext<cr>", { buffer = bufnr, desc = "Next symbol" })
      end,
    },
  },
}

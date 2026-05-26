return {
  {
    "mbbill/undotree",
    keys = {
      { "<leader>u", "<cmd>UndotreeToggle<cr>", desc = "Toggle undotree" },
    },
    init = function()
      vim.g.undotree_SetFocusWhenToggle = 1  -- focus panel on open
      vim.g.undotree_WindowLayout = 2        -- tree left, diff below
      vim.g.undotree_ShortIndicators = 1     -- compact time labels
      vim.g.undotree_SplitWidth = 30
    end,
  },
}

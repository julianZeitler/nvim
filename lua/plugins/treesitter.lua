local languages = {
  "python", "c", "typescript", "tsx", "rust", "lua", "vim", "vimdoc",
}

return {
  {
    "neovim-treesitter/nvim-treesitter",
    dependencies = { "neovim-treesitter/treesitter-parser-registry" },
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").install(languages)

      vim.api.nvim_create_autocmd("FileType", {
        pattern = languages,
        callback = function()
          vim.treesitter.start()
          vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
    end,
  },
}

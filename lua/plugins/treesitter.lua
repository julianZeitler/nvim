-- Parser names, as nvim-treesitter knows them.
local languages = {
  "python", "c", "typescript", "tsx", "rust", "lua", "vim", "vimdoc",
  "latex", "bibtex",
}

-- Filetypes to start treesitter on. Usually identical to the parser name, but
-- not always: the "latex" parser serves filetype "tex", and "bibtex" serves
-- "bib". Keying the autocmd off parser names would silently skip those.
local filetypes = {
  "python", "c", "typescript", "tsx", "rust", "lua", "vim", "vimdoc",
  "tex", "plaintex", "bib",
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
        pattern = filetypes,
        callback = function()
          local ok = pcall(vim.treesitter.start)
          if ok then
            vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },
}

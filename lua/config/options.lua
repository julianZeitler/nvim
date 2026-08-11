local opt = vim.opt

opt.number = true
opt.relativenumber = true

opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true

opt.wrap = false
opt.swapfile = false
opt.backup = false
opt.undofile = true
opt.undodir = vim.fn.expand("~/.local/share/nvim/undo")

opt.hlsearch = false
opt.incsearch = true
opt.termguicolors = true
opt.scrolloff = 8
opt.signcolumn = "yes"
opt.updatetime = 50
opt.splitright = true
opt.splitbelow = true
opt.mouse = "a"
opt.cursorline = true
opt.ignorecase = true
opt.smartcase = true

-- Treat .tex as LaTeX. Without this nvim guesses from the file contents and
-- falls back to "plaintex" for fragments that have no \documentclass -- which
-- is exactly what the section files under content/ look like.
vim.g.tex_flavor = "latex"

-- Prose wraps, code does not.
--
-- opt.wrap above stays false so long lines in code are visible as long lines.
-- Prose is the opposite: a paragraph is one very long line and reading it
-- needs soft wrapping. linebreak breaks at spaces rather than mid-word, and
-- breakindent keeps the continuation aligned under the first line.
--
-- <leader>tw toggles this per window if you want it off for a moment.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("ProseWrap", { clear = true }),
  pattern = { "tex", "plaintex", "markdown", "text", "gitcommit" },
  callback = function(args)
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.breakindent = true

    -- With wrap on, plain j/k jump over a whole wrapped paragraph. Moving by
    -- visual line is almost always what you want while writing. A count still
    -- means real lines, so 5j does what you expect.
    vim.keymap.set("n", "j", "v:count == 0 ? 'gj' : 'j'",
      { buffer = args.buf, expr = true, desc = "Down (visual line)" })
    vim.keymap.set("n", "k", "v:count == 0 ? 'gk' : 'k'",
      { buffer = args.buf, expr = true, desc = "Up (visual line)" })
  end,
})

-- netrw settings
vim.g.netrw_banner = 0                              -- hide banner (I)
vim.g.netrw_hide = 1                                -- enable hide list
vim.g.netrw_list_hide = [[\(^\|\s\s\)\zs\.\S\+]]   -- hide dotfiles

-- netrw tweaks
vim.api.nvim_create_autocmd("FileType", {
  pattern = "netrw",
  callback = function()
    vim.opt_local.number = true
    vim.opt_local.relativenumber = true
  end,
})

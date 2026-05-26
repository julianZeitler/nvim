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
opt.clipboard = "unnamedplus"
opt.cursorline = true
opt.ignorecase = true
opt.smartcase = true

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

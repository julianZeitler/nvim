vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("config.options")
require("config.keymaps")
require("config.lazy")
require("config.latex")
require("config.cheatsheet")
require("config.imgview").setup()
require("config.mathimg").setup()

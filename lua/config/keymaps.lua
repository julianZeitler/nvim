local map = vim.keymap.set

-- Render hover floats with a border. vim.lsp.with() is deprecated on 0.11+;
-- the options go straight to vim.lsp.buf.hover() instead (see the K map below).
local hover_opts = { border = "rounded", max_width = 80 }

-- LSP keymaps (set on attach)
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local map = function(keys, func, desc)
      vim.keymap.set("n", keys, func, { buffer = args.buf, desc = desc })
    end
    map("K",  function() vim.lsp.buf.hover(hover_opts) end, "Hover docs")
    map("gd", vim.lsp.buf.definition,     "Go to definition")
    map("gD", vim.lsp.buf.declaration,    "Go to declaration")
    map("gi", vim.lsp.buf.implementation, "Go to implementation")
    map("gr", vim.lsp.buf.references,     "References")
    map("<leader>rn", vim.lsp.buf.rename,     "Rename")
    map("<leader>ca", vim.lsp.buf.code_action,"Code action")
  end,
})

-- System clipboard (no global unnamedplus; use these explicitly)
map({ "n", "v" }, "<leader>y", '"+y', { desc = "Yank to clipboard" })
map("n", "<leader>Y", '"+Y', { desc = "Yank line to clipboard" })
map({ "n", "v" }, "<leader>p", '"+p', { desc = "Paste from clipboard" })
map({ "n", "v" }, "<leader>P", '"+P', { desc = "Paste before from clipboard" })

-- Jump back (after gd etc.)
map("n", "gb", "<C-o>", { desc = "Jump back" })

-- Diagnostics
map("n", "<leader>dt", function()
  local enabled = vim.diagnostic.is_enabled({ bufnr = 0 })
  vim.diagnostic.enable(not enabled, { bufnr = 0 })
  vim.notify("Diagnostics " .. (enabled and "disabled" or "enabled"), vim.log.levels.INFO)
end, { desc = "Toggle diagnostics" })
map("n", "D", function()
  vim.diagnostic.open_float({ border = "rounded" })
end, { desc = "Show diagnostic" })

-- Toggle soft wrap (global: useful in prose, logs and long lines anywhere).
-- linebreak/breakindent come along so wrapping breaks at words, not mid-word.
map("n", "<leader>tw", function()
  local on = not vim.wo.wrap
  vim.wo.wrap = on
  vim.wo.linebreak = on
  vim.wo.breakindent = on
  vim.notify("Wrap " .. (on and "on" or "off"), vim.log.levels.INFO)
end, { desc = "Toggle wrap" })

-- Window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })

-- Reads colorscheme from omarchy's current theme.
-- Filters out the LazyVim/LazyVim spec (not needed in vanilla lazy.nvim).
-- Sets up the colorscheme plugin and applies it.

local path = vim.fn.expand("~/.config/omarchy/current/theme/neovim.lua")
if vim.fn.filereadable(path) == 0 then
  return {}
end

local ok, specs = pcall(dofile, path)
if not ok or type(specs) ~= "table" then
  return {}
end

local colorscheme_name = nil
local plugin_specs = {}

for _, spec in ipairs(specs) do
  if type(spec[1]) == "string" and spec[1] == "LazyVim/LazyVim" then
    if spec.opts and spec.opts.colorscheme then
      colorscheme_name = spec.opts.colorscheme
    end
  else
    local s = vim.deepcopy(spec)
    s.lazy = false
    s.priority = 1000
    table.insert(plugin_specs, s)
  end
end

if colorscheme_name and plugin_specs[1] then
  -- Derive module name: "author/foo.nvim" -> "foo", "author/nvim-foo" -> "foo"
  local repo = plugin_specs[1][1]
  local mod = repo:match("[^/]+$"):gsub("%.nvim$", ""):gsub("^nvim%-", "")
  local original_opts = plugin_specs[1].opts

  plugin_specs[1].opts = nil
  plugin_specs[1].config = function(_, _)
    if original_opts then
      pcall(function() require(mod).setup(original_opts) end)
    end
    vim.cmd.colorscheme(colorscheme_name)
  end
end

return plugin_specs

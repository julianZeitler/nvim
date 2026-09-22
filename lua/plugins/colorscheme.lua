-- Reads colorscheme from omarchy's current theme.
-- Filters out the LazyVim/LazyVim spec (not needed in vanilla lazy.nvim).
-- Sets up the colorscheme plugin and applies it.

-- Omarchy quattro generates theme state into ~/.local/state/omarchy/current;
-- 3.8.x and earlier used ~/.config/omarchy/current. Probe both.
local path = nil
for _, candidate in ipairs({
  "~/.local/state/omarchy/current/theme/neovim.lua",
  "~/.config/omarchy/current/theme/neovim.lua",
}) do
  local expanded = vim.fn.expand(candidate)
  if vim.fn.filereadable(expanded) == 1 then
    path = expanded
    break
  end
end
if not path then
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

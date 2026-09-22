-- Display math in markdown, typeset by LaTeX and drawn as an image.
--
-- A `$$ ... $$` block is compiled with pdflatex, rasterised, and placed in the
-- buffer through image.nvim. The source lines are concealed, so what you see
-- is the formula the way LaTeX sets it -- real fractions, real integral signs,
-- matrices that line up.
--
-- Inline `$ ... $` is deliberately left alone. There is no way to reserve
-- horizontal space mid-sentence for an image, so every implementation of this
-- ends up putting inline math on its own line below the text, which reads
-- worse than the unicode render. render-markdown.nvim handles those through
-- utftex (see plugins/render-markdown.lua, `latex.inline`), and this module
-- takes only the blocks, which is why that config sets `latex.block = false`.
--
-- Rendering is cached on disk by formula and colour, so a file full of maths
-- only pays the LaTeX cost once.

local M = {}

local CACHE = vim.fn.stdpath("cache") .. "/mathimg"
local BUILD = CACHE .. "/build"
local NS = vim.api.nvim_create_namespace("mathimg")

local HAS_MAGICK = vim.fn.executable("magick") == 1

-- Point size of the formula in the LaTeX document. Only meaningful together
-- with the resolution it's rasterised at, below.
local FONT_PT = 12

local state = {} ---@type table<integer, { images: table<string, table>, timer: uv.uv_timer_t? }>
local enabled = true
local job = 0

local function magick_cmd(args)
  local cmd = HAS_MAGICK and { "magick" } or { "convert" }
  return vim.list_extend(cmd, args)
end

---------------------------------------------------------------------------
-- how big, and what colour
---------------------------------------------------------------------------

-- LaTeX is typeset at FONT_PT and rasterised at whatever resolution makes that
-- come out the size of the surrounding text. A terminal cell is roughly 1.25x
-- the font's em, and there are 72 points to the inch, so the dpi that matches
-- the editor's own text is (cell_height / 1.25) * (72 / FONT_PT).
local function resolution()
  local ok, imgview = pcall(require, "config.imgview")
  local cell = ok and imgview.cell_size() or { w = 9, h = 18 }
  local dpi = (cell.h / 1.25) * (72 / FONT_PT)
  return math.floor(math.min(math.max(dpi, 96), 600) + 0.5)
end

local function foreground()
  local hl = vim.api.nvim_get_hl(0, { name = "RenderMarkdownMath", link = false })
  if not hl or not hl.fg then
    hl = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  end
  if hl and hl.fg then
    return ("%06X"):format(hl.fg)
  end
  return vim.o.background == "dark" and "C0CAF5" or "1A1B26"
end

---------------------------------------------------------------------------
-- latex -> png
---------------------------------------------------------------------------

local TEMPLATE = [[
\documentclass[preview,border=2pt,%dpt]{standalone}
\usepackage{amsmath,amssymb,amsfonts,mathtools}
\usepackage{xcolor}
\begin{document}
\color[HTML]{%s}
$\displaystyle %s$
\end{document}
]]

--- @param formula string the maths, without its `$$` delimiters
--- @param cb fun(png: string|nil, err: string|nil)
local function compile(formula, cb)
  local fg, dpi = foreground(), resolution()
  local key = vim.fn.sha256(table.concat({ formula, fg, dpi, FONT_PT }, "\0")):sub(1, 32)
  local png = ("%s/%s.png"):format(CACHE, key)

  if vim.fn.filereadable(png) == 1 then
    cb(png, nil)
    return
  end

  job = job + 1
  local dir = ("%s/%d-%d"):format(BUILD, vim.fn.getpid(), job)
  vim.fn.mkdir(dir, "p")

  local tex = dir .. "/f.tex"
  vim.fn.writefile(vim.split(TEMPLATE:format(FONT_PT, fg, formula), "\n"), tex)

  local function done(err)
    vim.fn.delete(dir, "rf")
    cb(err and nil or png, err)
  end

  vim.system({
    "pdflatex", "-interaction=nonstopmode", "-halt-on-error",
    "-output-directory=" .. dir, tex,
  }, { text = true, cwd = dir }, vim.schedule_wrap(function(res)
    if res.code ~= 0 or vim.fn.filereadable(dir .. "/f.pdf") == 0 then
      -- The interesting line is the one starting with '!'; the rest is pages
      -- of package loading.
      local why = tostring(res.stdout):match("\n(![^\n]*)") or "pdflatex failed"
      done(why)
      return
    end

    -- Transparent background: the formula sits on whatever the colorscheme is
    -- using, and stays right if that changes underneath it.
    vim.system(
      magick_cmd({
        "-density", tostring(dpi), "-background", "none",
        dir .. "/f.pdf", "-trim", "+repage", "PNG32:" .. png,
      }),
      { text = true },
      vim.schedule_wrap(function(conv)
        done(conv.code ~= 0 and (conv.stderr or "convert failed") or nil)
      end)
    )
  end))
end

---------------------------------------------------------------------------
-- finding the blocks
---------------------------------------------------------------------------

--- @return { formula: string, row: integer, end_row: integer }[]
local function blocks(buf)
  local found = {}
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "markdown")
  if not ok or not parser then return found end

  pcall(parser.parse, parser, true)
  parser:for_each_tree(function(tree, ltree)
    if ltree:lang() ~= "markdown_inline" then return end
    local function walk(node)
      if node:type() == "latex_block" then
        local text = vim.treesitter.get_node_text(node, buf)
        -- `$$` marks display maths; a single `$` is inline and belongs to
        -- render-markdown's unicode path.
        local formula = text:match("^%$%$(.*)%$%$$")
        if formula and formula:match("%S") then
          local sr, _, er, ec = node:range()
          -- A node ending at column 0 stops on the line below the closing `$$`.
          if ec == 0 then er = er - 1 end
          found[#found + 1] = {
            formula = vim.trim(formula:gsub("%s+", " ")),
            row = sr,
            end_row = er,
          }
        end
        return
      end
      for child in node:iter_children() do walk(child) end
    end
    walk(tree:root())
  end)
  return found
end

---------------------------------------------------------------------------
-- drawing
---------------------------------------------------------------------------

local function clear(buf)
  local st = state[buf]
  if not st then return end
  for _, img in pairs(st.images) do
    pcall(function() img:clear() end)
  end
  st.images = {}
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
  end
end

-- Hide the source of a block. The first line stays as a real (blank) row for
-- the image to hang its virtual lines from; the rest are taken out of the
-- display entirely.
local function conceal(buf, row, end_row)
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
  vim.api.nvim_buf_set_extmark(buf, NS, row, 0, {
    end_row = row,
    end_col = #line,
    conceal = "",
  })
  for r = row + 1, end_row do
    vim.api.nvim_buf_set_extmark(buf, NS, r, 0, { conceal_lines = "" })
  end
end

local function draw(buf)
  if not enabled or not vim.api.nvim_buf_is_valid(buf) then return end
  local win = vim.fn.bufwinid(buf)
  if win == -1 then return end

  local ok, api = pcall(require, "image")
  if not ok then return end

  local st = state[buf]
  if not st then return end

  local wanted = blocks(buf)
  local keep = {}

  for _, block in ipairs(wanted) do
    local id = ("mathimg-%d-%d-%s"):format(buf, block.row, vim.fn.sha256(block.formula):sub(1, 16))
    keep[id] = true

    if st.images[id] then
      conceal(buf, block.row, block.end_row)
    else
      compile(block.formula, function(png, err)
        if err then
          vim.notify("mathimg: " .. err, vim.log.levels.WARN)
          return
        end
        -- The buffer may have moved on while LaTeX was running.
        if not state[buf] or not vim.api.nvim_buf_is_valid(buf) then return end
        local w = vim.fn.bufwinid(buf)
        if w == -1 then return end

        local img = api.from_file(png, {
          id = id,
          window = w,
          buffer = buf,
          x = 0,
          y = block.row,
          inline = true,
          with_virtual_padding = true,
        })
        if not img then return end
        st.images[id] = img
        conceal(buf, block.row, block.end_row)
        pcall(function() img:render() end)
      end)
    end
  end

  -- Blocks that have been edited away or moved.
  for id, img in pairs(st.images) do
    if not keep[id] then
      pcall(function() img:clear() end)
      st.images[id] = nil
    end
  end
end

local function schedule(buf)
  local st = state[buf]
  if not st then return end
  if not st.timer then st.timer = vim.uv.new_timer() end
  st.timer:stop()
  st.timer:start(120, 0, vim.schedule_wrap(function()
    -- Concealment is rebuilt from scratch each pass; stale marks would
    -- otherwise hide lines that are no longer maths.
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
    end
    draw(buf)
  end))
end

---------------------------------------------------------------------------
-- setup
---------------------------------------------------------------------------

local function attach(buf)
  if state[buf] then return end
  if vim.fn.executable("pdflatex") ~= 1 then return end
  state[buf] = { images = {} }
  vim.fn.mkdir(CACHE, "p")
  schedule(buf)
end

function M.setup()
  local group = vim.api.nvim_create_augroup("mathimg", { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "markdown",
    callback = function(ev) attach(ev.buf) end,
  })

  vim.api.nvim_create_autocmd({ "BufWinEnter", "TextChanged", "InsertLeave" }, {
    group = group,
    callback = function(ev)
      if state[ev.buf] then schedule(ev.buf) end
    end,
  })

  -- Editing inside a formula should show the formula, not a picture of it.
  vim.api.nvim_create_autocmd("InsertEnter", {
    group = group,
    callback = function(ev)
      if state[ev.buf] then clear(ev.buf) end
    end,
  })

  -- The rendered colour is baked into the png, so a new colorscheme needs new
  -- pngs. The cache is keyed on colour, so switching back is instant.
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function()
      for buf in pairs(state) do
        clear(buf)
        schedule(buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
    group = group,
    callback = function(ev)
      local st = state[ev.buf]
      if not st then return end
      clear(ev.buf)
      if st.timer then
        st.timer:stop()
        if not st.timer:is_closing() then st.timer:close() end
      end
      state[ev.buf] = nil
    end,
  })

  vim.api.nvim_create_user_command("MathImgToggle", function()
    enabled = not enabled
    for buf in pairs(state) do
      clear(buf)
      if enabled then schedule(buf) end
    end
    vim.notify("mathimg " .. (enabled and "on" or "off"))
  end, { desc = "Toggle typeset display maths" })

  vim.api.nvim_create_user_command("MathImgClearCache", function()
    vim.fn.delete(CACHE, "rf")
    vim.fn.mkdir(CACHE, "p")
    for buf in pairs(state) do
      clear(buf)
      schedule(buf)
    end
  end, { desc = "Drop rendered formula cache and redraw" })
end

return M

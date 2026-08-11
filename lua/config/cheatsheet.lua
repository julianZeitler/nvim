-- A paged keymap cheatsheet in a floating window.
--
--   <leader>?   open      (or :Cheatsheet)
--   l / n / →   next page
--   h / p / ←   previous page
--   1..9        jump to page
--   q / <Esc>   close
--
-- Page 1 is stock Vim. Everything after it is this config's own maps, grouped
-- by topic. When you add a keymap, add it here too -- nothing generates this
-- list automatically, so it is only as honest as you keep it.

local M = {}

local pages = {
  {
    title = "1. Vim Essentials",
    groups = {
      {
        name = "Motion",
        items = {
          { "h j k l", "left / down / up / right" },
          { "w  b  e", "next word / back / end of word" },
          { "0  ^  $", "line start / first non-blank / line end" },
          { "gg  G", "top of file / bottom of file" },
          { "{  }", "previous / next paragraph" },
          { "%", "jump to matching bracket" },
          { "f<c>  t<c>", "to char / before char (; and , to repeat)" },
          { "<C-u> <C-d>", "half page up / down" },
        },
      },
      {
        name = "Edit",
        items = {
          { "i  a  I  A", "insert before/after cursor, at line start/end" },
          { "o  O", "open line below / above" },
          { "x  r<c>", "delete char / replace char" },
          { "dd  yy  p", "delete line / yank line / paste" },
          { "d{motion}", "delete over motion (dw, d$, dip …)" },
          { "c{motion}", "change over motion" },
          { "u  <C-r>", "undo / redo" },
          { ".", "repeat last change" },
        },
      },
      {
        name = "Visual & Search",
        items = {
          { "v  V  <C-v>", "charwise / linewise / block visual" },
          { "gv", "reselect last visual selection" },
          { "/  ?", "search forward / backward" },
          { "n  N", "next / previous match" },
          { "*  #", "search word under cursor fwd / back" },
          { ":%s/a/b/g", "substitute in whole file" },
        },
      },
      {
        name = "Files, Buffers, Windows",
        items = {
          { ":w  :q  :wq", "write / quit / write and quit" },
          { ":e <file>", "open file" },
          { "<C-o> <C-i>", "jump back / forward in jumplist" },
          { ":bn  :bp  :bd", "next / previous / delete buffer" },
          { "<C-w>s  <C-w>v", "split horizontal / vertical" },
          { "<C-w>q", "close window" },
        },
      },
    },
  },

  {
    title = "2. Find & Navigate  (custom)",
    groups = {
      {
        name = "Telescope",
        items = {
          { "<leader>ff", "find files" },
          { "<leader>fc", "find in contents (live grep)" },
          { "<leader>fs", "find document symbols" },
        },
      },
      {
        name = "Harpoon",
        items = {
          { "<leader>h", "pin current file" },
          { "<leader>H", "open pinned menu" },
          { "<leader>1..5", "jump to pinned file 1-5" },
        },
      },
      {
        name = "Files & Structure",
        items = {
          { "<leader>e", "file explorer (netrw -- see page 3)" },
          { "<leader>o", "toggle symbol outline (aerial)" },
          { "[[  ]]", "previous / next symbol" },
          { "<leader>u", "toggle undotree" },
          { "gb", "jump back (after gd)" },
        },
      },
      {
        name = "Windows",
        items = {
          { "<C-h> <C-l>", "window left / right" },
          { "<C-j> <C-k>", "window down / up" },
        },
      },
    },
  },

  {
    -- netrw's own maps, from its quick reference (:h netrw-browse-maps).
    -- Descriptions note where this config changes the default behaviour.
    title = "3. Netrw file explorer",
    groups = {
      {
        name = "Open and move around",
        items = {
          { "<leader>e", "open netrw" },
          { "-", "up a directory (in a file: open netrw here)" },
          { "<CR>", "open file / enter directory" },
          { "u  U", "back / forward through visited dirs" },
          { "cd", "make the browsing dir the working dir" },
        },
      },
      {
        name = "Open somewhere else",
        items = {
          { "o  v  t", "open in split / vsplit / new tab" },
          { "p  P", "preview / open in previous window" },
          { "x", "open with the system program" },
        },
      },
      {
        name = "View",
        items = {
          { "i", "cycle thin / long / wide / tree listing" },
          { "gh", "toggle dotfiles (hidden here by default)" },
          { "I", "toggle the banner (off here by default)" },
          { "s  r", "sort by name/time/size  /  reverse" },
          { "<C-l>", "refresh the listing" },
        },
      },
      {
        name = "Create and modify",
        items = {
          { "%", "new file" },
          { "d", "new directory" },
          { "R", "rename" },
          { "D", "delete" },
          { "qf", "show file info" },
        },
      },
      {
        name = "Marked files",
        items = {
          { "mf  mu", "mark file / unmark all" },
          { "mt", "set this dir as the copy/move target" },
          { "mc  mm", "copy / move marked files to target" },
          { "mx", "run a shell command on marked files" },
        },
      },
    },
  },

  {
    title = "4. LSP & Diagnostics  (custom)",
    groups = {
      {
        name = "Navigate code",
        items = {
          { "gd", "go to definition" },
          { "gD", "go to declaration" },
          { "gi", "go to implementation" },
          { "gr", "references" },
          { "K", "hover documentation" },
        },
      },
      {
        name = "Change code",
        items = {
          { "<leader>rn", "rename symbol" },
          { "<leader>ca", "code action" },
        },
      },
      {
        name = "Diagnostics",
        items = {
          { "D", "show diagnostic under cursor" },
          { "<leader>dt", "toggle diagnostics in buffer" },
          { "]d  [d", "next / previous diagnostic" },
        },
      },
    },
  },

  {
    title = "5. Editing & Clipboard  (custom)",
    groups = {
      {
        name = "System clipboard",
        items = {
          { "<leader>y", "yank to clipboard (n, v)" },
          { "<leader>Y", "yank line to clipboard" },
          { "<leader>p", "paste from clipboard" },
          { "<leader>P", "paste before from clipboard" },
        },
      },
      {
        name = "View",
        items = {
          { "<leader>tw", "toggle soft wrap" },
        },
      },
    },
  },

  {
    title = "6. LaTeX  (custom)",
    groups = {
      {
        name = "Build",
        items = {
          { "<leader>ll", "build (runs project build.sh)" },
          { "<leader>lv", "open PDF at cursor (SyncTeX)" },
          { "<leader>le", "open build errors (quickfix)" },
          { ":LatexBuild", "build from anywhere" },
        },
      },
      {
        name = "Quickfix list",
        items = {
          { ":cn  :cp", "next / previous error" },
          { ":cclose", "close the error list" },
        },
      },
      {
        name = "Spelling",
        items = {
          { "<leader>ls", "toggle spell check" },
          { "]s  [s", "next / previous misspelling" },
          { "z=", "suggest corrections" },
          { "zg", "add word to dictionary" },
          { "zw", "mark word as wrong" },
        },
      },
      {
        name = "Completion (texlab)",
        items = {
          { "\\cite{", "citations from your .bib files" },
          { "\\ref{ \\cref{", "labels defined in the document" },
          { "\\includegraphics{", "image files only" },
          { "\\begin{", "environments" },
        },
      },
    },
  },
}

local state = { buf = nil, win = nil, page = 1 }

local function build_lines(page)
  local p = pages[page]
  local lines, marks = {}, {}

  local function add(text, hl, col_start, col_end)
    table.insert(lines, text)
    if hl then
      table.insert(marks, { row = #lines - 1, hl = hl, s = col_start or 0, e = col_end or -1 })
    end
  end

  add("  " .. p.title, "Title")
  add("")
  for _, g in ipairs(p.groups) do
    add("  " .. g.name, "Statement")
    for _, item in ipairs(g.items) do
      local key, desc = item[1], item[2]
      local text = string.format("    %-20s %s", key, desc)
      add(text)
      table.insert(marks, { row = #lines - 1, hl = "Identifier", s = 4, e = 4 + #key })
      table.insert(marks, { row = #lines - 1, hl = "Comment", s = 25, e = -1 })
    end
    add("")
  end

  local nav = string.format("  page %d/%d   l next   h prev   1-%d jump   q close",
    page, #pages, #pages)
  add(nav, "NonText")
  return lines, marks
end

local function draw()
  local lines, marks = build_lines(state.page)
  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  local ns = vim.api.nvim_create_namespace("cheatsheet")
  vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  for _, m in ipairs(marks) do
    local line = lines[m.row + 1] or ""
    local e = m.e == -1 and #line or math.min(m.e, #line)
    if m.s < #line and e > m.s then
      pcall(vim.api.nvim_buf_set_extmark, state.buf, ns, m.row, m.s,
        { end_col = e, hl_group = m.hl })
    end
  end
  vim.bo[state.buf].modifiable = false
end

local function close()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win, state.buf = nil, nil
end

function M.open()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    close()
    return
  end

  state.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.buf].bufhidden = "wipe"

  -- Size to the tallest page so paging does not resize the window underfoot.
  local height = 0
  for i = 1, #pages do
    height = math.max(height, #(select(1, build_lines(i))))
  end
  local width = math.min(78, vim.o.columns - 4)
  height = math.min(height, vim.o.lines - 6)

  state.win = vim.api.nvim_open_win(state.buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " Cheatsheet ",
    title_pos = "center",
  })
  vim.wo[state.win].wrap = false
  vim.wo[state.win].cursorline = false

  local function nav(delta)
    state.page = ((state.page - 1 + delta) % #pages) + 1
    draw()
  end

  local opts = { buffer = state.buf, nowait = true, silent = true }
  vim.keymap.set("n", "l", function() nav(1) end, opts)
  vim.keymap.set("n", "n", function() nav(1) end, opts)
  vim.keymap.set("n", "<Right>", function() nav(1) end, opts)
  vim.keymap.set("n", "h", function() nav(-1) end, opts)
  vim.keymap.set("n", "p", function() nav(-1) end, opts)
  vim.keymap.set("n", "<Left>", function() nav(-1) end, opts)
  vim.keymap.set("n", "q", close, opts)
  vim.keymap.set("n", "<Esc>", close, opts)
  for i = 1, math.min(#pages, 9) do
    vim.keymap.set("n", tostring(i), function()
      state.page = i
      draw()
    end, opts)
  end

  state.page = 1
  draw()
end

vim.api.nvim_create_user_command("Cheatsheet", M.open, {})
vim.keymap.set("n", "<leader>?", M.open, { desc = "Cheatsheet" })

return M

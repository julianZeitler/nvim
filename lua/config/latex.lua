-- LaTeX writing setup: prose-friendly options, spell checking, and a compile
-- keymap wired to the project's own build.sh.
--
-- Completion (commands, citations, \ref, image paths) comes from texlab -- see
-- lua/plugins/lsp.lua. The buffer-word source is disabled for tex in
-- lua/plugins/completion.lua.

local M = {}

local group = vim.api.nvim_create_augroup("LatexSetup", { clear = true })
local building = false

--- Walk up from the buffer to find the project root.
--- build.sh marks it; main.tex is the fallback for a bare document.
local function project_root(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  local dir = name ~= "" and vim.fs.dirname(name) or vim.fn.getcwd()
  for _, marker in ipairs({ "build.sh", "main.tex" }) do
    local hit = vim.fs.find({ marker }, { path = dir, upward = true, type = "file" })[1]
    if hit then
      return vim.fs.dirname(hit)
    end
  end
  return dir
end

--- Turn pdflatex output into quickfix entries.
--- build.sh passes -file-line-error, so errors arrive as "file.tex:12: message"
--- which needs no guessing about which file we are in.
local function parse_output(out, root)
  local items = {}
  for line in out:gmatch("[^\r\n]+") do
    local file, lnum, msg = line:match("^(.-%.tex):(%d+):%s*(.+)$")
    if file then
      if not file:match("^/") then
        file = root .. "/" .. file:gsub("^%./", "")
      end
      table.insert(items, { filename = file, lnum = tonumber(lnum), text = msg, type = "E" })
    else
      -- Undefined citations and references have no line number but are the
      -- single most common thing to go wrong in a paper, so surface them too.
      local warn = line:match("^LaTeX Warning: (Citation.+undefined.*)$")
        or line:match("^LaTeX Warning: (Reference.+undefined.*)$")
      if warn then
        table.insert(items, { filename = root .. "/main.tex", lnum = 0, text = warn, type = "W" })
      end
    end
  end
  return items
end

function M.compile(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if building then
    vim.notify("LaTeX: a build is already running", vim.log.levels.WARN)
    return
  end

  if vim.bo[buf].modified then
    vim.cmd("silent write")
  end

  local root = project_root(buf)
  local script = root .. "/build.sh"
  local cmd
  if vim.uv.fs_stat(script) then
    cmd = { script }
  else
    -- No build.sh: fall back to a plain single pass so the keymap still does
    -- something useful in a one-off document.
    local main = vim.uv.fs_stat(root .. "/main.tex") and "main.tex"
      or vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
    cmd = { "pdflatex", "-interaction=nonstopmode", "-file-line-error", main }
  end

  building = true
  vim.notify("LaTeX: building…", vim.log.levels.INFO)

  vim.system(cmd, { cwd = root, text = true }, function(res)
    vim.schedule(function()
      building = false
      local out = (res.stdout or "") .. "\n" .. (res.stderr or "")
      local items = parse_output(out, root)
      vim.fn.setqflist({}, "r", { title = "LaTeX build", items = items })

      local errors = 0
      for _, it in ipairs(items) do
        if it.type == "E" then errors = errors + 1 end
      end

      if res.code == 0 and errors == 0 then
        pcall(vim.cmd, "cclose")
        local extra = #items > 0 and (" (" .. #items .. " warnings)") or ""
        vim.notify("LaTeX: build succeeded" .. extra, vim.log.levels.INFO)
      else
        vim.notify("LaTeX: build failed (" .. errors .. " errors)", vim.log.levels.ERROR)
        if #items > 0 then
          pcall(vim.cmd, "copen")
        end
      end
    end)
  end)
end

--- Open the PDF at the position matching the cursor (SyncTeX forward search).
---
--- With zathura this also wires up inverse search: clicking a spot in the PDF
--- sends nvim back to the source line. zathura talks to the already-open
--- instance over D-Bus, so repeat calls move the existing window rather than
--- spawning a new one.
---
--- Without zathura it degrades to xdg-open, which shows the PDF but cannot
--- sync -- SyncTeX needs viewer support, not just the .synctex.gz file.
function M.view(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local root = project_root(buf)
  local pdf = root .. "/main.pdf"
  if not vim.uv.fs_stat(pdf) then
    vim.notify("LaTeX: no main.pdf yet -- build first (<leader>ll)", vim.log.levels.WARN)
    return
  end

  local file = vim.api.nvim_buf_get_name(buf)
  local pos = vim.api.nvim_win_get_cursor(0)
  local line, col = pos[1], pos[2] + 1

  if vim.fn.executable("zathura") == 0 then
    -- No zathura: fall back to the default handler. Viewers without SyncTeX
    -- (Firefox/pdf.js among them) can still be pointed at a page via the
    -- #page= fragment, so resolve the page ourselves. This is one-way and
    -- page-granular -- no highlight, and no clicking back to the source.
    local page
    local ok, res = pcall(function()
      return vim.system({ "synctex", "view", "-i",
        string.format("%d:%d:%s", line, col, file), "-o", pdf }, { text = true }):wait()
    end)
    if ok and res and res.stdout then
      page = res.stdout:match("Page:(%d+)")
    end
    local target = page and (pdf .. "#page=" .. page) or pdf
    vim.system({ "xdg-open", target }, { detach = true })
    vim.notify(
      "LaTeX: opened" .. (page and (" at page " .. page) or "") ..
      " without SyncTeX (install zathura for cursor-accurate sync)",
      vim.log.levels.WARN)
    return
  end

  -- v:servername is this nvim's RPC socket; passing it to zathura is what
  -- lets the PDF talk back to *this* instance rather than a stray one.
  local server = vim.v.servername
  local args = {
    "zathura",
    "--synctex-forward", string.format("%d:%d:%s", line, col, file),
  }

  -- Inverse search: ctrl-click in the PDF sends us back to the source line.
  -- The command handed to zathura is deliberately free of quotes and shell
  -- metacharacters -- a helper script takes the pieces as plain arguments.
  local helper = vim.fn.expand("~/.local/bin/zathura-nvim-synctex")
  if server ~= "" and vim.fn.executable(helper) == 1 then
    table.insert(args, "-x")
    table.insert(args, string.format("%s %s %%{input} %%{line}", helper, server))
  end

  table.insert(args, pdf)

  vim.system(args, { detach = true }, function(res)
    if res.code ~= 0 and res.code ~= nil then
      vim.schedule(function()
        vim.notify("LaTeX: zathura exited " .. res.code .. "\n" .. (res.stderr or ""),
          vim.log.levels.WARN)
      end)
    end
  end)
end

--- Turn a just-completed `\begin{name` into a whole environment block.
---
--- texlab completes the environment name only -- it returns plain text, not an
--- LSP snippet -- so accepting "equation" leaves you with a dangling \begin.
--- This finishes the job:
---
---     \begin{equation}
---         |
---     \end{equation}
---
--- Only fires when the \begin is the entire line up to the cursor, so it can
--- never eat text you already typed after it.
local function close_environment()
  if not vim.tbl_contains({ "tex", "plaintex" }, vim.bo.filetype) then
    return
  end

  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local before, rest = line:sub(1, col), line:sub(col + 1)

  -- Environment names are letters, sometimes with * or @.
  local indent, name = before:match("^(%s*)\\begin{([%a@]+%*?)}?$")
  if not name then return end
  if rest ~= "" and rest ~= "}" then return end

  local pad = vim.bo.expandtab
      and string.rep(" ", vim.bo.shiftwidth > 0 and vim.bo.shiftwidth or 4)
      or "\t"

  vim.api.nvim_buf_set_lines(0, row - 1, row, false, {
    indent .. "\\begin{" .. name .. "}",
    indent .. pad,
    indent .. "\\end{" .. name .. "}",
  })
  vim.api.nvim_win_set_cursor(0, { row + 1, #indent + #pad })
end

M.close_environment = close_environment

--- Remove the stray backslash left when a snippet is triggered as `\fig`.
---
--- blink's keyword does not include "\", so typing `\beg` replaces only "beg"
--- and the snippet body lands after the backslash you typed, giving
--- `\\begin{figure}`. LaTeX users type the backslash by reflex, so this is
--- easy to hit.
---
--- `\\` followed by a letter is never valid LaTeX -- `\\` is a line break and
--- is followed by end of line, whitespace, `*` or `[` -- so finding one is
--- unambiguous evidence of this mistake.
---
--- Deletes the single offending character rather than rewriting the line,
--- because the line still holds the snippet's tabstop extmarks and replacing
--- it wholesale would break `$1` mirroring into `\end{}`.
--- Searches upward from the cursor rather than only the current line: a
--- snippet's first tabstop is often below its first line (eq puts $1 in the
--- \label, align puts it in the first row), so the doubled backslash ends up
--- above wherever the cursor lands.
local function fix_stray_backslash()
  if not vim.tbl_contains({ "tex", "plaintex" }, vim.bo.filetype) then
    return
  end
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local first = math.max(1, row - 25)
  for r = row, first, -1 do
    local line = vim.api.nvim_buf_get_lines(0, r - 1, r, false)[1]
    if line then
      local col = line:find("\\\\%a")
      if col then
        vim.api.nvim_buf_set_text(0, r - 1, col - 1, r - 1, col, {})
        return
      end
    end
  end
end

vim.api.nvim_create_autocmd("User", {
  group = group,
  pattern = "BlinkCmpAccept",
  callback = function(ev)
    local item = ev.data and ev.data.item
    vim.schedule(function()
      if item and item.source_id == "snippets" then
        fix_stray_backslash()
      end
      close_environment()
    end)
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = { "tex", "plaintex", "bib" },
  callback = function(args)
    local o = vim.opt_local

    -- Wrap stays off by default, as everywhere else. Turn it on for a session
    -- with <leader>tw when you want to read a paragraph as it will be typeset.

    -- Move by visual line so that j/k behave sensibly *when* wrap is toggled
    -- on. With wrap off these are identical to plain j/k, so they cost nothing.
    local function m(lhs, rhs, desc)
      vim.keymap.set("n", lhs, rhs, { buffer = args.buf, expr = true, desc = desc })
    end
    m("j", "v:count == 0 ? 'gj' : 'j'", "Down (visual line)")
    m("k", "v:count == 0 ? 'gk' : 'k'", "Up (visual line)")

    -- Spell checking. "en" ships with nvim so this works offline; switch to
    -- en_us or en_gb if you want region-specific spellings (nvim will offer
    -- to download the file).
    o.spell = true
    o.spelllang = { "en" }

    local map = function(lhs, rhs, desc)
      vim.keymap.set("n", lhs, rhs, { buffer = args.buf, desc = desc })
    end
    map("<leader>ll", function() M.compile(args.buf) end, "LaTeX build")
    map("<leader>lv", function() M.view(args.buf) end, "LaTeX view PDF at cursor")
    map("<leader>le", "<cmd>copen<cr>", "LaTeX errors (quickfix)")
    map("<leader>ls", function()
      vim.opt_local.spell = not vim.opt_local.spell:get()
      vim.notify("Spell " .. (vim.opt_local.spell:get() and "on" or "off"))
    end, "Toggle spell")
  end,
})

vim.api.nvim_create_user_command("LatexBuild", function() M.compile() end, {})

return M

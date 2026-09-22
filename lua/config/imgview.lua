-- Viewing images and videos inside neovim.
--
-- Images
--   Opening one draws it in the window, scaled to fit, with zoom and pan on
--   top. Zoom is not an upscale of what you already see: the visible region is
--   cropped out of the original and scaled to the exact pixel size of the
--   window, so zooming in reveals real detail and 1:1 really is 1:1.
--
-- Videos
--   Neovim's own :terminal cannot speak the graphics protocol, so a video
--   cannot play inside a buffer. A video file opens as its poster frame (which
--   zooms and pans like any other image) plus the stream details, and playback
--   is handed to mpv -- either a normal window, or drawn in a new ghostty
--   window with mpv's kitty video output.
--
-- Rendering is done by image.nvim (see plugins/image.lua); everything here is
-- the geometry, the ImageMagick calls and the keymaps.

local M = {}

local IMAGE_EXT = {
  png = true, jpg = true, jpeg = true, gif = true, webp = true, avif = true,
  bmp = true, tif = true, tiff = true, ico = true, heic = true, svg = true,
}

local VIDEO_EXT = {
  mp4 = true, mkv = true, webm = true, mov = true, avi = true, m4v = true,
  wmv = true, flv = true, mpg = true, mpeg = true, ts = true, ogv = true,
}

local CACHE = vim.fn.stdpath("cache") .. "/imgview"

-- ImageMagick 7 ships a single `magick` binary; 6 (what Ubuntu still packages)
-- ships `convert` and `identify` separately.
local HAS_MAGICK = vim.fn.executable("magick") == 1

local function magick_cmd(args)
  local cmd = HAS_MAGICK and { "magick" } or { "convert" }
  return vim.list_extend(cmd, args)
end

local function identify_cmd(args)
  local cmd = HAS_MAGICK and { "magick", "identify" } or { "identify" }
  return vim.list_extend(cmd, args)
end

local function clamp(v, lo, hi)
  if hi < lo then return lo end
  return math.min(math.max(v, lo), hi)
end

---------------------------------------------------------------------------
-- terminal cell size
---------------------------------------------------------------------------

-- Placing an image needs its size in pixels, but a window measures itself in
-- cells. TIOCGWINSZ on stdout reports both, which gives us the conversion.
-- Terminals that don't fill in the pixel fields fall back to a typical cell.

local ffi_ok, ffi = pcall(require, "ffi")
local cdef_ok = false

local function cell_size()
  local fallback = { w = 9, h = 18 }
  if not ffi_ok then return fallback end

  if not cdef_ok then
    cdef_ok = pcall(ffi.cdef, [[
      typedef struct { unsigned short row, col, xpixel, ypixel; } imgview_winsize;
      int ioctl(int, unsigned long, ...);
    ]])
    if not cdef_ok then return fallback end
  end

  local ok, size = pcall(function()
    local TIOCGWINSZ = 0x5413 -- linux
    if jit.os == "OSX" or jit.os == "BSD" then TIOCGWINSZ = 0x40087468 end
    local ws = ffi.new("imgview_winsize")
    if ffi.C.ioctl(1, TIOCGWINSZ, ws) ~= 0 then return nil end
    if ws.col == 0 or ws.row == 0 or ws.xpixel == 0 or ws.ypixel == 0 then return nil end
    -- Kept fractional, the way image.nvim measures it. Rounding here and not
    -- there is a few pixels per cell, which across a hundred columns is enough
    -- to make our picture and the box it is placed in disagree.
    return { w = ws.xpixel / ws.col, h = ws.ypixel / ws.row }
  end)

  return (ok and size) or fallback
end

---------------------------------------------------------------------------
-- state
---------------------------------------------------------------------------

--- @class ImgviewState
--- @field path string file the buffer is showing
--- @field src string what we actually crop from (the file itself, a rasterised
---                   svg, or a video's poster frame)
--- @field sw integer source width in pixels
--- @field sh integer source height in pixels
--- @field zoom number 1 = fit the window
--- @field cx number centre of the viewport, 0..1 across the source
--- @field cy number
--- @field video? string video path, when this buffer is a video
--- @field info? string one-line description shown by <leader>? and on open
local state = {}

local function source_size(path)
  local res = vim.system(identify_cmd({ "-format", "%w %h", path .. "[0]" }), { text = true }):wait()
  local w, h = tostring(res.stdout):match("^(%d+)%s+(%d+)")
  if not w then return nil end
  return tonumber(w), tonumber(h)
end

-- Everything a render needs, derived from the window and the current zoom/pan.
-- `r*` is the rectangle of the source that is visible; `scale` is how many
-- screen pixels one source pixel occupies.
local function geometry(st, win)
  local cell = cell_size()
  local cols = vim.api.nvim_win_get_width(win)
  local rows = vim.api.nvim_win_get_height(win)
  if cols < 1 or rows < 1 or st.sw < 1 or st.sh < 1 then return nil end

  local vw = math.floor(cols * cell.w + 0.5)
  local vh = math.floor(rows * cell.h + 0.5)
  local fit = math.min(vw / st.sw, vh / st.sh)
  local scale = fit * st.zoom

  local rw = clamp(math.floor(vw / scale + 0.5), 1, st.sw)
  local rh = clamp(math.floor(vh / scale + 0.5), 1, st.sh)
  local rx = math.floor(clamp(st.cx * st.sw - rw / 2, 0, st.sw - rw) + 0.5)
  local ry = math.floor(clamp(st.cy * st.sh - rh / 2, 0, st.sh - rh) + 0.5)

  return {
    cols = cols, rows = rows, vw = vw, vh = vh,
    fit = fit, scale = scale,
    rw = rw, rh = rh, rx = rx, ry = ry,
  }
end

---------------------------------------------------------------------------
-- rendering
---------------------------------------------------------------------------

local function place(buf, g, file)
  local st = state[buf]
  if not st then return end
  local win = vim.fn.bufwinid(buf)
  if win == -1 then return end

  local ok, image = pcall(require, "image")
  if not ok then return end

  -- An image is bound to one window, so a split needs a fresh one.
  if st.img and st.win ~= win then
    pcall(function() st.img:clear() end)
    st.img = nil
  end

  if not st.img then
    st.win = win
    st.img = image.from_file(file, {
      id = "imgview-" .. buf,
      window = win,
      buffer = buf,
      x = 0,
      y = 0,
      width = g.cols,
      height = g.rows,
      max_width_window_percentage = 100,
      max_height_window_percentage = 100,
    })
    if not st.img then return end
    -- The percentage caps in plugins/image.lua are meant for images sitting
    -- inline in a document, where they mustn't push the text off screen. This
    -- viewer owns the whole window, so it opts out of them entirely -- without
    -- this it draws into a corner of the window at half size.
    st.img.ignore_global_max_size = true
  end

  -- Each render writes a new file. image.nvim decides whether it needs to
  -- reprocess by mtime, which has one-second resolution, and its transform
  -- cache is keyed on path plus mtime plus size -- both too coarse for keys
  -- held down. A fresh path per frame, and a cleared stamp, sidestep both.
  st.img.original_path = file
  st.img.path = file
  st.img.last_modified = -1
  pcall(function()
    st.img:render({ x = 0, y = 0, width = g.cols, height = g.rows })
  end)
end

local function do_render(buf)
  local st = state[buf]
  if not st or not st.src then return end
  local win = vim.fn.bufwinid(buf)
  if win == -1 then return end

  local g = geometry(st, win)
  if not g then return end

  -- One ImageMagick run at a time; a keypress during it queues a redo rather
  -- than piling up processes.
  if st.busy then
    st.again = true
    return
  end
  st.busy = true

  local ow = clamp(math.floor(g.rw * g.scale + 0.5), 1, g.vw)
  local oh = clamp(math.floor(g.rh * g.scale + 0.5), 1, g.vh)

  -- Never write over the file image.nvim is currently showing. It re-renders
  -- on its own schedule -- a window resize, a buffer switch -- and reading a
  -- half-written png throws from inside its callback, which surfaces as a
  -- stack trace over the editor.
  st.gen = (st.gen or 0) + 1
  local out = ("%s/render-%d-%d.png"):format(CACHE, buf, st.gen)

  local args = { st.src .. "[0]" }
  vim.list_extend(args, { "-crop", ("%dx%d+%d+%d"):format(g.rw, g.rh, g.rx, g.ry), "+repage" })
  -- Past ~1.5x the interesting thing is the pixels themselves, so stop
  -- smoothing them away.
  if g.scale > 1.5 then
    vim.list_extend(args, { "-filter", "Point" })
  end
  vim.list_extend(args, { "-resize", ("%dx%d"):format(ow, oh) })
  -- Pad out to the exact window box so image.nvim's own fitting is a no-op and
  -- the picture is never scaled twice.
  vim.list_extend(args, {
    "-background", "none",
    "-gravity", "center",
    "-extent", ("%dx%d"):format(g.vw, g.vh),
    "PNG32:" .. out,
  })

  vim.system(magick_cmd(args), { text = true }, vim.schedule_wrap(function(res)
    st.busy = false
    if not state[buf] then return end
    if res.code ~= 0 then
      vim.notify("imgview: ImageMagick failed\n" .. (res.stderr or ""), vim.log.levels.ERROR)
      return
    end
    place(buf, g, out)
    -- Keep the frame before this one around: image.nvim may still be holding it
    -- while it finishes a render of its own.
    st.files[#st.files + 1] = out
    while #st.files > 2 do
      pcall(vim.fn.delete, table.remove(st.files, 1))
    end
    if st.again then
      st.again = false
      do_render(buf)
    end
  end))
end

local function render(buf)
  local st = state[buf]
  if not st then return end
  if not st.timer then st.timer = vim.uv.new_timer() end
  st.timer:stop()
  st.timer:start(20, 0, vim.schedule_wrap(function() do_render(buf) end))
end

---------------------------------------------------------------------------
-- actions
---------------------------------------------------------------------------

local function status(buf)
  local st = state[buf]
  if not st then return end
  local win = vim.fn.bufwinid(buf)
  local g = win ~= -1 and geometry(st, win) or nil
  local parts = {
    vim.fn.fnamemodify(st.path, ":t"),
    ("%dx%d"):format(st.sw, st.sh),
  }
  if g then
    parts[#parts + 1] = ("%.0f%%"):format(g.scale * 100)
  end
  if st.info then parts[#parts + 1] = st.info end
  vim.api.nvim_echo({ { table.concat(parts, "  ") } }, false, {})
end

local function zoom_by(buf, factor)
  local st = state[buf]
  if not st then return end
  st.zoom = clamp(st.zoom * factor, 0.05, 64)
  render(buf)
  status(buf)
end

local function pan_by(buf, dx, dy)
  local st = state[buf]
  if not st then return end
  local win = vim.fn.bufwinid(buf)
  local g = win ~= -1 and geometry(st, win) or nil
  if not g then return end
  -- Step a fraction of what's on screen, so panning feels the same at any zoom
  -- and does nothing when the whole image already fits.
  st.cx = clamp(st.cx + dx * (g.rw / st.sw), 0, 1)
  st.cy = clamp(st.cy + dy * (g.rh / st.sh), 0, 1)
  render(buf)
end

local function reset(buf)
  local st = state[buf]
  if not st then return end
  st.zoom, st.cx, st.cy = 1, 0.5, 0.5
  render(buf)
  status(buf)
end

-- Zoom so one source pixel is one screen pixel.
local function actual_size(buf)
  local st = state[buf]
  if not st then return end
  local win = vim.fn.bufwinid(buf)
  local g = win ~= -1 and geometry(st, win) or nil
  if not g or g.fit == 0 then return end
  st.zoom = 1 / g.fit
  render(buf)
  status(buf)
end

local function open_external(buf)
  local st = state[buf]
  if not st then return end
  for _, cmd in ipairs({ "imv", "swayimg", "nsxiv", "feh", "xdg-open" }) do
    if vim.fn.executable(cmd) == 1 then
      vim.system({ cmd, st.path }, { detach = true })
      return
    end
  end
  vim.notify("imgview: no external image viewer found", vim.log.levels.WARN)
end

local HELP = {
  { "+ =",            "zoom in" },
  { "- _",            "zoom out" },
  { "scroll wheel",   "zoom" },
  { "h j k l, arrows", "pan" },
  { "H J K L",        "pan faster" },
  { "0",              "fit to window" },
  { "1",              "actual size (1:1)" },
  { "o",              "open in an external viewer" },
  { "q",              "close" },
  { "g?",             "this help" },
}

local function help(buf)
  local lines = {}
  if state[buf] and state[buf].video then
    lines[#lines + 1] = { "<CR>", "play in mpv" }
    lines[#lines + 1] = { "t", "play in a ghostty window, drawn in the terminal" }
  end
  vim.list_extend(lines, HELP)
  local chunks = {}
  for _, l in ipairs(lines) do
    chunks[#chunks + 1] = { ("  %-16s"):format(l[1]), "Special" }
    chunks[#chunks + 1] = { l[2] .. "\n" }
  end
  vim.api.nvim_echo(chunks, true, {})
end

---------------------------------------------------------------------------
-- video
---------------------------------------------------------------------------

local function play_external(buf)
  local st = state[buf]
  if not st or not st.video then return end
  if vim.fn.executable("mpv") ~= 1 then
    vim.notify("imgview: mpv is not installed", vim.log.levels.ERROR)
    return
  end
  vim.system({ "mpv", "--", st.video }, { detach = true })
end

-- mpv can draw video with the same graphics protocol the images use, but it
-- has to own a terminal to do it -- neovim's :terminal doesn't forward the
-- protocol -- so it gets a ghostty window of its own.
local function play_in_terminal(buf)
  local st = state[buf]
  if not st or not st.video then return end
  if vim.fn.executable("mpv") ~= 1 then
    vim.notify("imgview: mpv is not installed", vim.log.levels.ERROR)
    return
  end
  if vim.fn.executable("ghostty") ~= 1 then
    vim.notify("imgview: ghostty not on PATH; use <CR> instead", vim.log.levels.WARN)
    return
  end
  vim.system({
    "ghostty", "-e",
    "mpv", "--vo=kitty", "--vo-kitty-use-shm=yes", "--profile=sw-fast",
    "--really-quiet", "--", st.video,
  }, { detach = true })
end

local function probe(path)
  if vim.fn.executable("ffprobe") ~= 1 then return nil, nil end
  local res = vim.system({
    "ffprobe", "-v", "error", "-select_streams", "v:0",
    "-show_entries", "stream=width,height,codec_name",
    "-show_entries", "format=duration",
    "-of", "default=noprint_wrappers=1", path,
  }, { text = true }):wait()
  if res.code ~= 0 then return nil, nil end

  local out = tostring(res.stdout)
  local fields = {}
  for k, v in out:gmatch("(%w+)=([^\n]+)") do fields[k] = v end

  local duration = tonumber(fields.duration)
  local bits = {}
  if fields.codec_name then bits[#bits + 1] = fields.codec_name end
  if duration then
    bits[#bits + 1] = ("%d:%02d"):format(math.floor(duration / 60), math.floor(duration % 60))
  end
  return duration, (#bits > 0 and table.concat(bits, "  ") or nil)
end

---------------------------------------------------------------------------
-- opening a buffer
---------------------------------------------------------------------------

local function map(buf, lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { buffer = buf, silent = true, desc = desc })
end

local function set_keymaps(buf)
  map(buf, "+", function() zoom_by(buf, 1.25) end, "Zoom in")
  map(buf, "=", function() zoom_by(buf, 1.25) end, "Zoom in")
  map(buf, "-", function() zoom_by(buf, 0.8) end, "Zoom out")
  map(buf, "_", function() zoom_by(buf, 0.8) end, "Zoom out")
  map(buf, "<ScrollWheelUp>", function() zoom_by(buf, 1.15) end, "Zoom in")
  map(buf, "<ScrollWheelDown>", function() zoom_by(buf, 1 / 1.15) end, "Zoom out")

  for keys, d in pairs({
    h = { -1, 0 }, l = { 1, 0 }, j = { 0, 1 }, k = { 0, -1 },
    ["<Left>"] = { -1, 0 }, ["<Right>"] = { 1, 0 },
    ["<Down>"] = { 0, 1 }, ["<Up>"] = { 0, -1 },
  }) do
    map(buf, keys, function() pan_by(buf, d[1] * 0.15, d[2] * 0.15) end, "Pan")
  end
  for keys, d in pairs({ H = { -1, 0 }, L = { 1, 0 }, J = { 0, 1 }, K = { 0, -1 } }) do
    map(buf, keys, function() pan_by(buf, d[1] * 0.5, d[2] * 0.5) end, "Pan (fast)")
  end

  map(buf, "0", function() reset(buf) end, "Fit to window")
  map(buf, "1", function() actual_size(buf) end, "Actual size")
  map(buf, "o", function() open_external(buf) end, "Open externally")
  map(buf, "q", "<cmd>bdelete<cr>", "Close")
  map(buf, "g?", function() help(buf) end, "Help")

  if state[buf] and state[buf].video then
    map(buf, "<CR>", function() play_external(buf) end, "Play in mpv")
    map(buf, "t", function() play_in_terminal(buf) end, "Play in the terminal")
  end
end

-- Window options that would otherwise draw over or shift the picture. They are
-- window-local, so the previous values are put back when the buffer leaves.
local WIN_OPTS = {
  number = false, relativenumber = false, cursorline = false, cursorcolumn = false,
  list = false, wrap = false, spell = false, foldcolumn = "0", signcolumn = "no",
  colorcolumn = "", statuscolumn = "",
  -- The buffer is one blank line, so without this a column of ~ runs down the
  -- side of the picture.
  fillchars = "eob: ",
}

local function apply_win_opts(win)
  local saved = vim.w[win] and vim.w[win].imgview_saved
  if saved then return end
  saved = {}
  for name, value in pairs(WIN_OPTS) do
    saved[name] = vim.api.nvim_get_option_value(name, { win = win, scope = "local" })
    vim.api.nvim_set_option_value(name, value, { win = win, scope = "local" })
  end
  vim.w[win].imgview_saved = saved
end

local function restore_win_opts(win)
  if not vim.api.nvim_win_is_valid(win) then return end
  local saved = vim.w[win].imgview_saved
  if not saved then return end
  for name, value in pairs(saved) do
    pcall(vim.api.nvim_set_option_value, name, value, { win = win, scope = "local" })
  end
  vim.w[win].imgview_saved = nil
end

local function cleanup(buf)
  local st = state[buf]
  if not st then return end
  if st.timer then
    st.timer:stop()
    if not st.timer:is_closing() then st.timer:close() end
  end
  if st.img then pcall(function() st.img:clear() end) end
  for _, f in ipairs(st.files or {}) do pcall(vim.fn.delete, f) end
  for _, f in ipairs({ st.raster, st.poster }) do
    if f then pcall(vim.fn.delete, f) end
  end
  state[buf] = nil
end

-- Start showing st.src once its pixel size is known.
local function begin(buf)
  local st = state[buf]
  if not st then return end
  local sw, sh = source_size(st.src)
  if not sw then
    vim.notify("imgview: could not read " .. st.src, vim.log.levels.ERROR)
    return
  end
  st.sw, st.sh = sw, sh
  set_keymaps(buf)
  render(buf)
  status(buf)
end

local function open(buf, path)
  vim.fn.mkdir(CACHE, "p")

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
  vim.bo[buf].buftype = "nowrite"
  vim.bo[buf].swapfile = false
  vim.bo[buf].undofile = false
  vim.bo[buf].filetype = "imgview"

  local ext = path:match("%.([^.]+)$")
  ext = ext and ext:lower() or ""

  state[buf] = {
    path = path,
    files = {},
    zoom = 1, cx = 0.5, cy = 0.5,
  }
  local st = state[buf]

  local win = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_buf(win) == buf then apply_win_opts(win) end

  if VIDEO_EXT[ext] then
    if vim.fn.executable("ffmpeg") ~= 1 then
      vim.notify("imgview: ffmpeg is needed to show a video's poster frame", vim.log.levels.WARN)
      return
    end
    st.video = path
    st.poster = ("%s/poster-%d.png"):format(CACHE, buf)

    local duration, info = probe(path)
    st.info = info and (info .. "  <CR> to play") or "<CR> to play"
    -- A tenth of the way in, to skip the black frames films tend to open on.
    local seek = duration and ("%.2f"):format(duration * 0.1) or "0"

    vim.system({
      "ffmpeg", "-v", "error", "-y", "-ss", seek, "-i", path,
      "-frames:v", "1", st.poster,
    }, { text = true }, vim.schedule_wrap(function(res)
      if not state[buf] then return end
      if res.code ~= 0 or vim.fn.filereadable(st.poster) == 0 then
        vim.notify("imgview: could not extract a frame from " .. vim.fn.fnamemodify(path, ":t"),
          vim.log.levels.ERROR)
        return
      end
      st.src = st.poster
      begin(buf)
    end))
    return
  end

  if ext == "svg" then
    -- An svg has no pixels of its own, so rasterise it generously once and zoom
    -- into that. 2000px wide is past what a terminal window can show.
    st.raster = ("%s/raster-%d.png"):format(CACHE, buf)
    vim.system(
      magick_cmd({ "-background", "none", "-density", "384", path, "-resize", "2000x2000>", "PNG32:" .. st.raster }),
      { text = true },
      vim.schedule_wrap(function(res)
        if not state[buf] then return end
        if res.code ~= 0 then
          vim.notify("imgview: could not rasterise the svg\n" .. (res.stderr or ""), vim.log.levels.ERROR)
          return
        end
        st.src = st.raster
        begin(buf)
      end)
    )
    return
  end

  st.src = path
  begin(buf)
end

---------------------------------------------------------------------------
-- setup
---------------------------------------------------------------------------

-- Prints what the viewer thinks the geometry is, against what image.nvim went
-- on to do with it. The two disagreeing is what makes a picture land in a
-- corner or come out clipped.
local function debug_dump()
  local buf = vim.api.nvim_get_current_buf()
  local st = state[buf]
  if not st then
    vim.notify("imgview: this buffer isn't an image view", vim.log.levels.WARN)
    return
  end

  local cell = cell_size()
  local win = vim.fn.bufwinid(buf)
  local g = win ~= -1 and geometry(st, win) or nil
  local lines = {
    ("source          %s  %dx%d"):format(st.path, st.sw or -1, st.sh or -1),
    ("cell            %.3f x %.3f px"):format(cell.w, cell.h),
    ("window          %d x %d cells"):format(
      win ~= -1 and vim.api.nvim_win_get_width(win) or -1,
      win ~= -1 and vim.api.nvim_win_get_height(win) or -1),
  }
  if g then
    lines[#lines + 1] = ("viewport        %d x %d px"):format(g.vw, g.vh)
    lines[#lines + 1] = ("zoom            %.3f  (scale %.3f, fit %.3f)"):format(st.zoom, g.scale, g.fit)
    lines[#lines + 1] = ("crop            %dx%d+%d+%d"):format(g.rw, g.rh, g.rx, g.ry)
  end
  lines[#lines + 1] = ("frame           %s"):format(st.files[#st.files] or "none yet")

  local ok, image = pcall(require, "image")
  if ok then
    local ts = require("image/utils/term").get_size()
    if ts then
      lines[#lines + 1] = ("image.nvim cell %.3f x %.3f px  (screen %dx%d cells)"):format(
        ts.cell_width, ts.cell_height, ts.screen_cols, ts.screen_rows)
    end
    if st.img then
      lines[#lines + 1] = ("image.nvim got  %dx%d px"):format(st.img.image_width or -1, st.img.image_height or -1)
      local rg = st.img.rendered_geometry or {}
      lines[#lines + 1] = ("image.nvim drew x=%s y=%s %sx%s cells"):format(
        tostring(rg.x), tostring(rg.y), tostring(rg.width), tostring(rg.height))
      lines[#lines + 1] = ("caps ignored    %s"):format(tostring(st.img.ignore_global_max_size))
    end
    local _ = image
  end

  vim.api.nvim_echo(vim.tbl_map(function(l) return { l .. "\n" } end, lines), true, {})
end

function M.setup()
  -- Frames left behind by a previous session, or by a crash.
  for _, f in ipairs(vim.fn.glob(CACHE .. "/render-*.png", false, true)) do
    pcall(vim.fn.delete, f)
  end

  vim.api.nvim_create_user_command("ImgviewDebug", debug_dump, { desc = "imgview geometry report" })

  local patterns = {}
  for ext in pairs(IMAGE_EXT) do patterns[#patterns + 1] = "*." .. ext end
  for ext in pairs(VIDEO_EXT) do patterns[#patterns + 1] = "*." .. ext end

  local group = vim.api.nvim_create_augroup("imgview", { clear = true })

  -- BufReadCmd, not BufReadPost: it stops neovim loading the bytes at all,
  -- which matters for a 2GB video as much as it does for a jpeg.
  vim.api.nvim_create_autocmd("BufReadCmd", {
    group = group,
    pattern = patterns,
    callback = function(ev)
      if vim.fn.filereadable(ev.match) == 0 then return end
      if not HAS_MAGICK and vim.fn.executable("convert") ~= 1 then
        vim.notify("imgview: ImageMagick is not installed", vim.log.levels.ERROR)
        return
      end
      open(ev.buf, vim.fn.fnamemodify(ev.match, ":p"))
    end,
  })

  -- Writing an image buffer would truncate the file to the one blank line.
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    group = group,
    pattern = patterns,
    callback = function(ev)
      vim.bo[ev.buf].modified = false
      vim.notify("imgview: this buffer is a view, not the file", vim.log.levels.WARN)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufWinEnter", "WinResized", "VimResized" }, {
    group = group,
    callback = function()
      for buf in pairs(state) do
        local win = vim.fn.bufwinid(buf)
        if win ~= -1 then
          apply_win_opts(win)
          render(buf)
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufWinLeave", {
    group = group,
    callback = function(ev)
      if state[ev.buf] then restore_win_opts(vim.api.nvim_get_current_win()) end
    end,
  })

  vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
    group = group,
    callback = function(ev) cleanup(ev.buf) end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      for buf in pairs(state) do cleanup(buf) end
    end,
  })
end

-- Shared with config/mathimg.lua, which needs the same pixels-per-cell to size
-- what it renders.
M.cell_size = cell_size

return M

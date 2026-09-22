-- Inline images in the terminal, via kitty's graphics protocol.
--
-- Ghostty speaks that protocol, so nothing terminal-side needs configuring.
-- ImageMagick does the scaling: the `magick` (v7) or `convert` (v6) CLI has to
-- be on PATH. `build = false` keeps lazy from compiling the magick Lua rock,
-- which the CLI processor makes unnecessary.
--
-- hijack_file_patterns is deliberately empty. Opening an image file is handled
-- by config/imgview.lua instead, which adds zoom and pan on top of the
-- rendering this plugin provides.
return {
  {
    "3rd/image.nvim",
    build = false,
    lazy = false,
    opts = {
      backend = "kitty",
      processor = "magick_cli",

      integrations = {
        -- Images referenced from a markdown file render under the link. Only
        -- the one under the cursor: with every image in the file drawn at
        -- once the virtual padding fights render-markdown.nvim's extmarks,
        -- which is the arrangement its own docs recommend.
        markdown = {
          enabled = true,
          clear_in_insert_mode = true,
          download_remote_images = true,
          only_render_image_at_cursor = true,
          only_render_image_at_cursor_mode = "inline",
          filetypes = { "markdown", "vimwiki", "quarto" },
        },
        neorg = { enabled = false },
        typst = { enabled = false },
        html = { enabled = false },
        css = { enabled = false },
      },

      -- Inline images in a document are capped at half the window so they don't
      -- push the surrounding text off screen. The standalone viewer in
      -- config/imgview.lua sizes itself and ignores these.
      max_width_window_percentage = nil,
      max_height_window_percentage = 50,

      -- Redraw when a float (completion menu, hover) covers the image, otherwise
      -- the image paints over it.
      window_overlap_clear_enabled = true,
      window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "blink-cmp-menu", "blink-cmp-documentation" },

      hijack_file_patterns = {},
    },
  },
}

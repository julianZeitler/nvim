-- Markdown rendered in place: headings with icons and a coloured background,
-- code blocks as filled boxes, real bullets and checkboxes, drawn tables,
-- callouts, and latex formulas turned into unicode.
--
-- It draws with extmarks over the real text rather than replacing it, so the
-- buffer is still plain markdown and still editable. anti_conceal (on by
-- default) shows the raw source on whatever line the cursor is on, so you edit
-- the markup you wrote and see the result everywhere else.
--
-- It stays out of image.nvim's way by design; the two render different things.
return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "neovim-treesitter/nvim-treesitter" },
    ft = { "markdown" },
    opts = {
      -- Callout and checkbox completions in blink.
      completions = { blink = { enabled = true } },

      -- Formulas are turned into unicode box-art. Needs the `latex` treesitter
      -- parser (already there for .tex) and a converter: the default order is
      -- utftex then latex2text, and utftex is the one built into ~/.local --
      -- it parses the formula properly, so fractions, roots, integrals and
      -- matrices come out as structure rather than as a line of symbols.
      -- Inline only. `$$ ... $$` blocks are handled by config/mathimg.lua,
      -- which compiles them with pdflatex and draws the result as an image;
      -- leaving `block` on here would render both.
      latex = { enabled = true, inline = true, block = false },

      code = {
        -- Box the block at its own width instead of the whole window, which
        -- reads better next to prose.
        width = "block",
        min_width = 45,
        left_pad = 2,
        right_pad = 2,
      },

      heading = {
        -- No level glyphs. An empty string still counts as an icon, so the
        -- '#' markers are overlaid with blanks rather than left showing --
        -- which is what an empty list would do. What's left is the colour and
        -- the offset the markers occupied, one column deeper per level.
        icons = { "" },
        -- Nothing in the sign column either.
        sign = false,
        width = "block",
        min_width = 45,
      },

      -- Everything under a heading indents to match it, org-mode style. Plain
      -- whitespace: an empty icon drops the guide bar it would otherwise draw.
      indent = {
        enabled = true,
        icon = "",
        per_level = 2,
        skip_level = 1,
      },
    },
  },
}

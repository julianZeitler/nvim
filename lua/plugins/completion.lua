return {
  {
    "saghen/blink.cmp",
    version = "1.*",
    opts = {
      keymap = {
        -- The "enter" preset makes <CR> accept the selected item. It falls
        -- back to a normal newline whenever the menu is not open, so Enter
        -- only ever "steals" a keypress while a suggestion is on screen.
        preset = "enter",
        -- Keep the default accept key too, for when you want a newline with
        -- the menu still open: <C-y> accepts, Enter breaks the line.
        ["<C-y>"] = { "select_and_accept", "fallback" },
      },
      appearance = {
        nerd_font_variant = "mono",
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },

        -- In prose the buffer source is pure noise: it proposes every word
        -- already on screen, which is never what you want mid-sentence.
        -- texlab supplies the real completions (commands, citations, refs,
        -- graphics paths), so LaTeX gets LSP only.
        per_filetype = {
          tex      = { "lsp", "path", "snippets" },
          plaintex = { "lsp", "path", "snippets" },
          bib      = { "lsp", "path" },
        },
      },
      completion = {
        list = {
          selection = {
            -- First item is highlighted as soon as the menu opens, so the
            -- common case is just <CR>.
            preselect = true,
            -- Highlighting alone does not touch the buffer -- the text is
            -- written when you accept, not while you move through the list.
            auto_insert = false,
          },
        },
        -- \cite{ opens a long candidate list; showing the entry's title and
        -- author makes it pickable without memorising citation keys.
        documentation = { auto_show = true, auto_show_delay_ms = 150 },
      },
      -- blink's fuzzy matcher (frecency + proximity, both on by default)
      -- already handles typo-tolerant subsequence matching, so "lejepa" finds
      -- balestrieroLeJEPAProvableScalable2025 in \cite{}. Nothing to configure.
      signature = { enabled = true },
    },
  },
}

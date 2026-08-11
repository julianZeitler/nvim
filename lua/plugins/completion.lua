return {
  {
    "saghen/blink.cmp",
    version = "1.*",
    opts = {
      keymap = { preset = "default" },
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

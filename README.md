# rails-tools.nvim

A Neovim plugin for Ruby on Rails development. Zero-config, discoverable, context-aware.

## Status

🚧 **Under active development.** The sections from [Installation](#installation)
onward also list planned features; unchecked items there are not available yet.
See [specs/story.md](specs/story.md) for the full tracker and
[specs/issues/](specs/issues/) for per-feature specs.

**Implemented:**
- [x] Rails project detection
- [x] RSpec/Minitest detection, Grape API detection
- [x] Plugin entry point — `init.lua`, `setup()`, `plugin/`, the `:Rails` command
- [x] Configuration system (`config.lua` is the single source of truth for
      alternate mappings; `core/alternate.lua` reads from it)
- [x] Terminal abstraction (toggleterm or native terminal), health check (`:checkhealth rails-tools`)
- [x] Alternate file navigation (app ↔ spec/test, including nested namespaces)
- [x] Resource finder, Telescope pickers, central menu (`:Rails`), default keymaps
- [x] Routes navigator, Rails console, Rails runner
- [x] RSpec runner — nearest spec, spec file, re-run last (opt-in: `modules.rspec = true`)
- [x] Rails generators — `:Rails generate {args}` (opt-in: `modules.generators = true`)
- [x] Schema-aware editing for ActiveRecord columns, from `db/schema.rb` +
      `annotate` blocks: hover (`K`), go-to-definition (`gd`), `nvim-cmp`
      completion (see
      [021-schema-inspector.md](specs/issues/021-schema-inspector.md))

**Not implemented yet:**
- [ ] Grape support, test marker, context-aware `gf`,
      controller ↔ view navigation (Phase 2, opt-in modules)
- [ ] Rails engines inside a host app, projects that only have `db/structure.sql`
- [ ] Schema table display — `:Rails schema {table}` (Phase 3 — see
      [028-schema-display.md](specs/issues/028-schema-display.md))
- Log viewer, Rails doctor, code extraction, syntax highlighting are in the
  experimental backlog, not scheduled

## Requirements

- Neovim 0.9+
- A Rails project

**Optional:** [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim), [toggleterm.nvim](https://github.com/akinsho/toggleterm.nvim), [which-key.nvim](https://github.com/folke/which-key.nvim)

## Installation

```lua
-- lazy.nvim
{
  "nxhung2304/rails-tools.nvim",
  ft = { "ruby", "eruby" },
  config = function()
    require("rails-tools").setup()
  end,
}
```

## Configuration

Zero-config works out of the box. Override only what you need:

```lua
require("rails-tools").setup({
  modules = {
    rspec      = true,   -- RSpec runner (default: false)
    generators = true,   -- Rails generators (default: false)
    grape      = true,   -- Grape API support (default: false)
  },
  terminal = {
    provider  = "auto",        -- "auto" | "toggleterm" | "native"
    direction = "float",       -- "float" | "horizontal" | "vertical"
  },
  keymaps = {
    enabled = true,
    prefix  = "<leader>r",
  },
  alternate = {
    custom_mappings = {
      { pattern = "app/forms/(.+)_form.rb$",      target = "spec/forms/%1_form_spec.rb" },
      { pattern = "spec/forms/(.+)_form_spec.rb$", target = "app/forms/%1_form.rb" },
    },
  },
  cmp = {
    dedupe_with_lsp = { "ruby_lsp" },  -- skip the rails_schema source when these LSP clients are attached
  },
})
```

## Usage

### Central Menu

```
:Rails
```

Opens an interactive menu showing all available actions for the current file context.

### Commands

`:Rails` is wired up with a subcommand dispatch table; with no subcommand it
opens the central menu (see [Status](#status) for what is still to come).

- [x] `:Rails` — Open central menu
- [x] `:Rails alternate` — Toggle between implementation and spec file
- [x] `:Rails find {type}` — Find resources (`models`, `controllers`,
      `views`, `specs`, …)
- [x] `:Rails routes` — Browse and navigate routes
- [x] `:Rails routes!` — Force refresh routes cache
- [x] `:Rails console` — Open Rails console
- [x] `:Rails runner {code}` — Run a Ruby snippet via `rails runner`
- [x] `:Rails runner` — Open prompt to enter code
- [x] `:Rails generate {args}` — Run a Rails generator
- [x] `:Rails spec nearest` — Run the spec nearest to cursor
- [x] `:Rails spec file` — Run the current spec file
- [x] `:Rails spec last` — Re-run the last spec
- [ ] `:Rails grape routes` — Browse Grape API endpoints
- [ ] `:Rails doctor` — Diagnose project issues _(experimental backlog)_

### Keymaps

Default prefix: `<leader>r` (change with `keymaps.prefix`, turn off with
`keymaps.enabled = false`). Set `vim.g.mapleader` before calling `setup()`:
`<leader>` is resolved when the keymap is created.

- [x] `<leader>rr` — `:Rails` (open menu)
- [x] `<leader>ra` — `:Rails alternate`
- [x] `<leader>rf` — find any resource (same as the menu's Find Resource)
- [x] `<leader>ro` — `:Rails routes`
- [x] `<leader>rc` — `:Rails console`
- [x] `<leader>rx` — `:Rails runner` (prompt)
- [x] `<leader>rs` — `:Rails spec nearest` _(requires `modules.rspec = true`)_
- [x] `<leader>rS` — `:Rails spec file` _(requires `modules.rspec = true`)_
- [x] `<leader>rg` — `:Rails generate` _(requires `modules.generators = true`)_

### Telescope Integration

Loaded automatically when telescope.nvim is already loaded when `setup()` runs.

- [x] `:Telescope rails models`
- [x] `:Telescope rails controllers`
- [x] `:Telescope rails routes`
- [x] `:Telescope rails specs`
- [x] Falls back to `vim.ui.select` when Telescope is not available

### Health Check

- [x] `:checkhealth rails-tools` — Neovim version, Rails detection, optional dependencies, enabled modules

## License

MIT

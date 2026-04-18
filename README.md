# rails-tools.nvim

A Neovim plugin for Ruby on Rails development. Zero-config, discoverable, context-aware.

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
})
```

## Usage

### Central Menu

```
:Rails
```

Opens an interactive menu showing all available actions for the current file context.

### Commands

| Command | Description |
|---------|-------------|
| `:Rails` | Open central menu |
| `:Rails alternate` | Toggle between implementation and spec file |
| `:Rails find {type}` | Find resources (`models`, `controllers`, `views`, `specs`, …) |
| `:Rails routes` | Browse and navigate routes |
| `:Rails routes!` | Force refresh routes cache |
| `:Rails console` | Open Rails console |
| `:Rails runner {code}` | Run a Ruby snippet via `rails runner` |
| `:Rails runner` | Open prompt to enter code |
| `:Rails generate {args}` | Run a Rails generator |
| `:Rails spec nearest` | Run the spec nearest to cursor |
| `:Rails spec file` | Run the current spec file |
| `:Rails spec last` | Re-run the last spec |
| `:Rails grape routes` | Browse Grape API endpoints |
| `:Rails doctor` | Diagnose project issues |

### Keymaps

Default prefix: `<leader>r`

| Keymap | Action |
|--------|--------|
| `<leader>rr` | `:Rails` — Open menu |
| `<leader>ra` | `:Rails alternate` |
| `<leader>rf` | `:Rails find` |
| `<leader>ro` | `:Rails routes` |
| `<leader>rc` | `:Rails console` |
| `<leader>rx` | `:Rails runner` (prompt) |
| `<leader>rs` | `:Rails spec nearest` _(requires `modules.rspec = true`)_ |
| `<leader>rS` | `:Rails spec file` _(requires `modules.rspec = true`)_ |
| `<leader>rg` | `:Rails generate` _(requires `modules.generators = true`)_ |

### Telescope Integration

When telescope.nvim is installed, all pickers automatically use Telescope:

```vim
:Telescope rails models
:Telescope rails controllers
:Telescope rails routes
:Telescope rails specs
```

Falls back to `vim.ui.select` when Telescope is not available.

### Health Check

```vim
:checkhealth rails-tools
```

## License

MIT

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## MCP
- Github: https://github.com/nxhung2304/rails-tools.nvim

## Project Overview

**rails-tools.nvim** is a Neovim plugin for Ruby on Rails development, written in Lua. Design philosophy: **zero-config, discoverable, context-aware, single entry point** (`:Rails` command).

- **Minimum Neovim:** 0.9+
- **Required dependencies:** None (Neovim native APIs only)
- **Optional dependencies:** telescope.nvim, toggleterm.nvim, which-key.nvim
- **Test framework:** plenary.nvim test harness

## Commands

```bash
make test                              # Run all tests
make test-file FILE=tests/path/to_spec.lua  # Run single test file
make lint                              # Run luacheck
```

> Note: This project is currently in the **specification phase**. No Lua code or Makefile exists yet. When implementing, create the Makefile with the commands above.

## Architecture

### Directory Layout (target)

```
lua/rails-tools/
├── init.lua          -- Entry point: setup(), exposes public API
├── config.lua        -- Default config + deep merge logic
├── commands.lua      -- :Rails and all user commands
├── keymaps.lua       -- Keymap registration (prefix: <leader>r)
├── utils.lua         -- Shared utilities
├── cache.lua         -- TTL cache (routes, schema)
├── health.lua        -- :checkhealth rails-tools
├── detectors/        -- Auto-detection modules
│   ├── rails.lua     -- Detect Rails root via Gemfile + bin/rails
│   ├── rspec.lua     -- Detect RSpec vs Minitest
│   └── grape.lua     -- Detect Grape API gem
├── core/             -- Feature modules
│   ├── alternate.lua -- Toggle impl ↔ spec file
│   ├── finder.lua    -- Resource picker (telescope or vim.ui.select)
│   ├── routes.lua    -- Parse config/routes.rb, navigate routes
│   ├── generators.lua
│   ├── console.lua
│   └── runner.lua
├── telescope/init.lua -- Telescope extension (optional)
├── integrations/
│   ├── rspec.lua     -- Run nearest/file/last spec
│   ├── grape.lua     -- Grape API support
│   └── test_marker.lua
└── ui/
    ├── menu.lua      -- :Rails central menu via vim.ui.select
    └── terminal.lua  -- Abstraction: toggleterm or native split
plugin/
└── rails-tools.lua   -- Lazy-load registration
tests/                -- mirrors lua/ structure, files end in _spec.lua
doc/rails-tools.txt   -- Vimdoc
```

### Key Design Patterns

**Detector API** — all detectors return structured results and cache themselves:
```lua
detector.detect()   -- -> { is_rails = true, root = "/path" } | nil
detector.root()     -- -> string | nil
detector.is_rails() -- -> boolean
```

**Provider pattern** — terminal and finder both support `provider = "auto" | "toggleterm" | "native"`. Auto-detects the best available option and falls back gracefully.

**Config merge** — always use `vim.tbl_deep_extend("force", defaults, user_config)`. Custom alternate mappings are prepended (higher priority than defaults).

**Cache** — routes and schema results use a TTL cache (default 300s). Cache is keyed by Rails root path.

### Module Phases

| Phase | Issues | Features |
|-------|--------|----------|
| 1 MVP | 001–013 | Detection, alternate file, finder, routes, console, runner, menu, keymaps, terminal |
| 2 Extended | 014–018 | RSpec runner, generators, Grape support, test marker |
| 3 Polish | 019–022 | Schema inspector, log viewer, Rails doctor, docs |

Modules for Phase 2+ are disabled by default in config (`modules.rspec = false`, etc.) and must be explicitly enabled by the user.

## Specifications

All feature specifications live in `specs/issues/NNN-name.md`. The master technical spec is `specs/story.md`. Each issue file contains: Description, Design, Acceptance Criteria, Implementation Checklist, and Notes.

When implementing a feature, read its issue spec first and follow the Implementation Checklist exactly.

## Coding Conventions

- All public APIs must include LuaDoc annotations (`---@param`, `---@return`)
- Module files return a table `M` — no global state
- All subcommands dispatch through a single `:Rails` command — register and route them in `commands.lua` via a subcommand dispatch table, not as separate `vim.api.nvim_create_user_command` calls
- If a dependency (telescope, toggleterm) is missing, degrade gracefully — never error, just fall back
- Test files: `tests/<subdir>/<module>_spec.lua`, use plenary.nvim `describe/it` blocks

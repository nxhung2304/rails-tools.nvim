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

## Architecture

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

## Specifications

All feature specifications live in `specs/issues/NNN-name.md`. The master technical spec is `specs/story.md`. Each issue file contains: Description, Design, Acceptance Criteria, Implementation Checklist, and Notes.

Work through tasks in the order they appear in `specs/story.md`; do not implement Backlog items unless explicitly asked.

When implementing a feature, read its issue spec first and follow the Implementation Checklist exactly.

## Coding Conventions

- All public APIs must include LuaDoc annotations (`---@param`, `---@return`)
- Module files return a table `M` — no global state
- All subcommands dispatch through a single `:Rails` command — register and route them in `commands.lua` via a subcommand dispatch table, not as separate `vim.api.nvim_create_user_command` calls
- If a dependency (telescope, toggleterm) is missing, degrade gracefully — never error, just fall back
- Phase 2 modules are disabled by default in config (`modules.rspec = false`, etc.) and must be explicitly enabled by the user
- Test files: `tests/<subdir>/<module>_spec.lua`, use plenary.nvim `describe/it` blocks

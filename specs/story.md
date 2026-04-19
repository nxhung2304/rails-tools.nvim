# rails-tools.nvim - Implementation Checklist

## Overview

**rails-tools.nvim** is a Neovim plugin for Ruby on Rails development, written in Lua.
Design philosophy: **zero-config, discoverable, context-aware, single entry point**.

---

## Dependency Layers

Tasks are organized by dependency order. Lower layers MUST be completed before higher layers.

```
Layer 0: Foundation (test environment)
    ↓
Layer 1: Core Infrastructure (config, terminal, entry points)
    ↓
Layer 2: Detection Layer (project detection)
    ↓
Layer 3: Core Features (main functionality)
    ↓
Layer 4: Enhanced Navigation (Phase 2)
    ↓
Layer 5: Polish & Integrations (Phase 3)
```

---

## Progress Summary

| Layer | Tasks | Completed | Progress |
|-------|-------|-----------|----------|
| Layer 0 - Foundation | 1 task | 1 | 100% |
| Layer 1 - Infrastructure | 4 tasks | 2 | 50% |
| Layer 2 - Detection | 4 tasks | 2 | 50% |
| Layer 3 - Core Features | 8 tasks | 1 | 13% |
| Layer 4 - Enhanced | 6 tasks | 0 | 0% |
| Layer 5 - Polish | 7 tasks | 0 | 0% |

### Completed Items ✅
- **L0-000** - Test Application (000-test-app.md)
- **L1-004** - Configuration System (001-config-system.md)
- **L2-001** - Rails Detection (003-rails-detection.md)
- **L2-002** - Test Framework Detection (004-rspec-minitest-detection.md)
- **L3-003** - Alternate File Navigation (007-alternate-file.md)

### In Progress 🚧
- **L1-004** - Configuration System (needs full setup(), get(), defaults)

### Next Steps 📋 (In dependency order)
1. **Complete L1-004** - Config System (setup(), get(), defaults)
2. **Implement L1-013** - Terminal Abstraction (needed by Console/Runner)
3. **Implement L1-Entry** - init.lua, commands.lua, utils.lua, plugin/
4. **Implement L2-005** - Health Check (can verify detectors)
5. **Continue L3** - Finder, Telescope, Menu, Keymaps, Routes, Console, Runner

---

## Layer 0 — Foundation

### L0-000. Test Application (000-test-app.md)
- [x] Create test Rails application at `test-app/`
- [x] Add models, controllers, views, specs
- [x] Add Grape API endpoints
- [ ] Setup script for test environment

---

## Layer 1 — Core Infrastructure

**IMPORTANT**: This layer MUST be completed first. All other layers depend on it.

### L1-004. Configuration System (001-config-system.md) ⚠️ CRITICAL PATH
- [x] Create `lua/rails-tools/config.lua`
- [ ] Define `M.defaults` with all settings
- [ ] Implement `M.setup(user_config)` with deep merge
- [ ] Implement `M.get()` function
- [ ] Support zero-config (nil config)
- [ ] Create tests for config module
- [ ] Default config includes:
  - [ ] Module enable/disable (all 27 modules)
  - [ ] Terminal settings (provider, direction, sizes)
  - [ ] Finder settings (provider, resources, cache_ttl)
  - [ ] Routes settings (command, args, cache_ttl)
  - [ ] Console settings (command)
  - [ ] Runner settings (command)
  - [ ] Keymaps (enabled, prefix)
  - [ ] Alternate file mappings (custom_mappings) ✅
  - [ ] View engine detection
  - [ ] RSpec settings
  - [ ] Syntax highlighting settings
  - [ ] Integration settings

### L1-013. Terminal Abstraction Layer (002-terminal-abstraction.md) ⚠️ NEEDED BY L3-011, L3-012
- [ ] Create `lua/rails-tools/ui/terminal.lua`
- [ ] Implement `open(cmd, opts)`, `toggle()`, `send(text)` functions
- [ ] Implement provider detection (auto, toggleterm, native)
- [ ] Implement toggleterm backend
- [ ] Implement native terminal backend
- [ ] Support directions: float, horizontal, vertical
- [ ] Configurable sizes: float (width, height), horizontal (rows), vertical (columns)
- [ ] Create tests for terminal module
- [ ] Test each provider and direction

### L1-Entry. Plugin Entry Points
- [ ] Create `lua/rails-tools/init.lua` - Entry point with setup()
- [ ] Create `lua/rails-tools/commands.lua` - Command dispatcher
- [ ] Create `lua/rails-tools/utils.lua` - Shared utilities
- [ ] Create `lua/rails-tools/cache.lua` - Shared cache (needed by Routes, Schema)
- [ ] Create `plugin/rails-tools.lua` - Lazy-load registration
- [x] Create Makefile with test, lint targets
- [x] Setup plenary.nvim test harness

---

## Layer 2 — Detection Layer

**Depends on**: Layer 1 (Config for detector settings)

### L2-001. Rails Detection (003-rails-detection.md)
- [x] Create `lua/rails-tools/detectors/init.lua`
- [x] Create `lua/rails-tools/detectors/rails.lua`
- [x] Implement `detect()`, `root()`, `is_rails()` functions
- [x] Add caching by root path
- [ ] Handle monorepos, Rails engines, edge cases
- [x] Create `tests/detectors/rails_spec.lua`

### L2-002. Test Framework Detection (004-rspec-minitest-detection.md)
- [x] Create `lua/rails-tools/detectors/test_framework.lua`
- [x] Implement `detect()`, `is_rspec()`, `is_minitest()` functions
- [x] Check spec/ directory → RSpec
- [x] Check test/ directory → Minitest
- [x] Handle projects with both directories
- [x] Create `tests/detectors/test_framework_spec.lua`

### L2-005. Health Check (005-health-check.md)
- [ ] Create `lua/rails-tools/health.lua`
- [ ] Implement `M.check()` function
- [ ] Check Neovim version (>= 0.9)
- [ ] Check Rails detection status
- [ ] Check Ruby and Rails versions
- [ ] Check optional dependencies (telescope, toggleterm, which-key)
- [ ] Check project details (Gemfile, bin/rails, test framework, Grape)
- [ ] Check module status (enabled/disabled)
- [ ] Format output with vim.health API

### L2-016. Grape API Detection (016-grape-api-detection.md) [Phase 2]
- [ ] Create `lua/rails-tools/detectors/grape.lua`
- [ ] Implement `detect()` function
- [ ] Check app/api/ directory existence
- [ ] Check Gemfile for grape gem
- [ ] Both conditions must be true
- [ ] Create `tests/detectors/grape_spec.lua`

---

## Layer 3 — Core Features (Phase 1 MVP)

**Depends on**: Layer 1 (Config, Terminal), Layer 2 (Detectors)

### L3-003. Alternate File Navigation (007-alternate-file.md)
- [x] Create `lua/rails-tools/core/alternate.lua`
- [x] Implement `open()`, `get(filepath)` functions
- [x] Add default mappings in config:
  - [x] Model ↔ Spec
  - [x] Controller ↔ Request Spec
  - [x] Service ↔ Spec
  - [x] Policy ↔ Spec
  - [x] Job ↔ Spec
  - [x] Mailer ↔ Spec
  - [x] Serializer ↔ Spec
- [x] Support custom_mappings override
- [ ] Handle nested namespaces
- [x] Prompt to create file if alternate doesn't exist
- [x] Create `tests/core/alternate_spec.lua`

### L3-006. Resource Finder (008-resource-finder.md)
- [ ] Create `lua/rails-tools/core/finder.lua`
- [ ] Define resource_paths table
- [ ] Implement `find(resource_type)` function
- [ ] Implement directory scanning
- [ ] Integrate with Telescope (when available)
- [ ] Implement vim.ui.select fallback
- [ ] Cache results with 30s TTL
- [ ] Resources: models, controllers, views, services, policies, jobs, mailers, serializers, specs, factories
- [ ] Create `tests/core/finder_spec.lua`

### L3-007. Telescope Integration (009-telescope-pickers.md)
- [ ] Create `lua/rails-tools/telescope/init.lua`
- [ ] Define exports table for Telescope registration
- [ ] Implement pickers: models, controllers, views, services, specs, routes
- [ ] Add grape picker (placeholder for Phase 2)
- [ ] Register extension
- [ ] Gracefully handle missing telescope.nvim
- [ ] Test each picker

### L3-008. Rails Menu (010-menu.md)
- [ ] Create `lua/rails-tools/ui/menu.lua`
- [ ] Implement `M.open()` function
- [ ] Define menu items table
- [ ] Filter items based on enabled modules
- [ ] Always show: Alternate File, Find Resource
- [ ] Conditional items based on module config
- [ ] Register `:Rails` command in commands.lua
- [ ] Create `:Rails` command dispatch

### L3-009. Keymap Registration (011-keymaps.md)
- [ ] Create `lua/rails-tools/keymaps.lua`
- [ ] Implement `M.setup()` function
- [ ] Define default keymap bindings
- [ ] Support configurable prefix (default: `<leader>r`)
- [ ] Check `config.keymaps.enabled` before registering
- [ ] Keymaps:
  - [ ] `<leader>rr` - Rails menu
  - [ ] `<leader>ra` - Alternate file
  - [ ] `<leader>rf` - Resource finder
  - [ ] `<leader>ro` - Routes navigator
  - [ ] `<leader>rc` - Console
  - [ ] `<leader>rx` - Runner
- [ ] Create tests for keymap registration

### L3-010. Routes Navigator (012-routes-navigator.md)
- [ ] Create `lua/rails-tools/core/routes.lua`
- [ ] Implement `show()`, `refresh()`, `goto_action()` functions
- [ ] Implement async shell command runner (vim.fn.jobstart)
- [ ] Parse `bin/rails routes --expanded` output
- [ ] Parse controller#action → file and method
- [ ] Implement method line finder
- [ ] Integrate with cache.lua (from L1-Entry)
- [ ] Cache with TTL from config (default 300s)
- [ ] Handle namespaced routes
- [ ] Show loading indicator
- [ ] Force refresh with `:Rails routes!`
- [ ] Create `tests/core/routes_spec.lua`

### L3-011. Rails Console (013-console.md)
- [ ] Create `lua/rails-tools/core/console.lua`
- [ ] Implement `open()`, `toggle()` functions
- [ ] Integrate with ui/terminal.lua (from L1-013)
- [ ] Read `config.console.command`
- [ ] Register `:Rails console` subcommand
- [ ] Create tests for console module

### L3-012. Rails Runner (014-runner.md)
- [ ] Create `lua/rails-tools/core/runner.lua`
- [ ] Implement `run(code)`, `run_prompt()`, `run_visual()` functions
- [ ] Integrate with ui/terminal.lua (from L1-013)
- [ ] Read `config.runner.command`
- [ ] Register `:Rails runner {code}` subcommands
- [ ] Create tests for runner module

---

## Layer 4 — Enhanced Navigation (Phase 2)

**Depends on**: Layer 3 (Core Features)

### L4-014. RSpec Runner (015-rspec-runner.md)
- [ ] Create `lua/rails-tools/integrations/rspec.lua`
- [ ] Implement `run_nearest()`, `run_file()`, `run_last()` functions
- [ ] Display test results
- [ ] Handle test failures
- [ ] Cache last executed spec
- [ ] Register commands: `:Rails spec nearest`, `:Rails spec file`, `:Rails spec last`
- [ ] Register keymaps: `<leader>rs`, `<leader>rS`
- [ ] Only active when `modules.rspec = true`
- [ ] Create tests for RSpec runner

### L4-015. Rails Generators (016-generators.md)
- [ ] Create `lua/rails-tools/core/generators.lua`
- [ ] Implement `run(args)` function
- [ ] Support model, controller, migration generation
- [ ] Display generator output
- [ ] Register `:Rails generate {args}` command
- [ ] Register keymap: `<leader>rg`
- [ ] Only active when `modules.generators = true`
- [ ] Create `tests/core/generators_spec.lua`

### L4-017. Grape API Support (017-grape-support.md)
- [ ] Create `lua/rails-tools/integrations/grape.lua`
- [ ] Implement Grape routes parser
- [ ] Implement endpoint finder
- [ ] Display Grape endpoints in picker
- [ ] Register `:Rails grape routes` command
- [ ] Integrate with Telescope
- [ ] Only active when `modules.grape = true`
- [ ] Create `tests/integrations/grape_spec.lua`

### L4-018. Test Marker (018-test-marker.md)
- [ ] Create `lua/rails-tools/integrations/test_marker.lua`
- [ ] Implement `is_focused()`, `focus()`, `unfocus()`, `toggle()` functions
- [ ] Support RSpec syntax (fit, fdescribe, fcontext)
- [ ] Only active when `modules.test_marker = true`
- [ ] Create tests for test marker

### L4-019. Context-Aware gf (019-context-aware-gf.md)
- [ ] Create `lua/rails-tools/core/gf.lua`
- [ ] Implement context detection (Treesitter + regex fallback)
- [ ] Implement partial path parser: `"shared/header"` → `app/views/shared/_header.html.erb`
- [ ] Implement fixture finder: `:users` → `test/fixtures/users.yml`
- [ ] Implement migration finder: `User` → latest `db/migrate/*_create_users.rb`
- [ ] Implement route finder: route name → controller#action
- [ ] Support visual selection for complex paths
- [ ] Detect view engine: .erb, .haml, .slim
- [ ] Detect format: .html, .json, .xml
- [ ] Fallback to default `gf` if no Rails context
- [ ] Only active when `modules.gf = true`
- [ ] Create `tests/core/gf_spec.lua`

### L4-020. Controller-View Navigation (020-controller-view-navigation.md)
- [ ] Create `lua/rails-tools/core/controller_view.lua`
- [ ] Implement `to_view()` - Controller action → View
- [ ] Implement `views_for_controller()` - List all views
- [ ] Implement `from_view()` - View → Controller
- [ ] Implement related files: helper, schema, layout, fixture, migration
- [ ] Implement `related_menu()` - Show available related files
- [ ] Register `:R [type]` and `:Rails related [type]` commands
- [ ] Register keymap: `<leader>rv`
- [ ] Smart view engine detection (.erb, .haml, .slim)
- [ ] Smart format detection (.html, .json, .xml)
- [ ] Handle namespaced controllers
- [ ] Prompt to create missing views
- [ ] Only active when `modules.controller_view = true`
- [ ] Create `tests/core/controller_view_spec.lua`

---

## Layer 5 — Polish & Integrations (Phase 3)

**Depends on**: Layer 4 (Enhanced Navigation)

### L5-021. Schema Inspector (021-schema-inspector.md)
- [ ] Create `lua/rails-tools/core/schema.lua`
- [ ] Implement schema parser for db/schema.rb
- [ ] Display table structures
- [ ] Show column names and types
- [ ] Show indexes
- [ ] Integrate with cache.lua
- [ ] Integrate with Telescope
- [ ] Only active when `modules.schema = true`
- [ ] Create `tests/core/schema_spec.lua`

### L5-022. Log Viewer (022-log-viewer.md)
- [ ] Create `lua/rails-tools/core/log_viewer.lua`
- [ ] Implement log parser
- [ ] Implement filter by level (debug, info, warn, error)
- [ ] Auto-detect log directory
- [ ] Support tailing logs
- [ ] Integrate with Telescope
- [ ] Only active when `modules.log_viewer = true`
- [ ] Create tests for log viewer

### L5-023. Rails Doctor (023-rails-doctor.md)
- [ ] Create `lua/rails-tools/core/doctor.lua`
- [ ] Implement migration check
- [ ] Implement gem check
- [ ] Implement other diagnostic checks
- [ ] Display diagnostic results with suggestions
- [ ] Run async with TTL cache
- [ ] Register `:Rails doctor` command
- [ ] Only active when `modules.doctor = true`
- [ ] Create tests for Rails doctor

### L5-024. Documentation (024-documentation.md)
- [ ] Complete README.md with all features
- [ ] Complete doc/rails-tools.txt (Vimdoc)
- [ ] Document all commands
- [ ] Document all keymaps
- [ ] Provide usage examples
- [ ] Create migration guide
- [ ] Review documentation completeness

### L5-025. Code Extraction (025-code-extraction.md)
- [ ] Create `lua/rails-tools/core/extractor.lua`
- [ ] Implement `extract_visual(filename, mode)` function
- [ ] Implement partial extraction (views)
- [ ] Implement concern extraction (models/controllers)
- [ ] Implement helper extraction
- [ ] Detect and prompt for local variables
- [ ] Register `:Extract {filename}` and `:Rails extract {filename}` commands
- [ ] Support .erb, .haml, .slim engines
- [ ] Only active when `modules.extractor = true`
- [ ] Create `tests/core/extractor_spec.lua`

### L5-026. Syntax Highlighting (026-syntax-highlighting.md)
- [ ] Create `lua/rails-tools/core/syntax.lua`
- [ ] Create `syntax/rails.vim`
- [ ] Create `after/syntax/ruby/rails.vim`
- [ ] Define Rails keyword groups
- [ ] Create highlight groups: RailsAssociation, RailsValidation, RailsCallback, RailsHelper, RailsMacro
- [ ] Create Treesitter queries for Rails methods
- [ ] Implement regex fallback for older Neovim
- [ ] Support user-defined keywords via config
- [ ] Add `config.syntax` settings
- [ ] Create `tests/core/syntax_spec.lua`

### L5-027. Optional Integrations (027-optional-integrations.md)
- [ ] Create `lua/rails-tools/integrations/detector.lua` - Detect installed plugins
- [ ] Create `lua/rails-tools/integrations/manager.lua` - Manage integrations
- [ ] Database Integration (vim-dadbod)
  - [ ] Create `lua/rails-tools/integrations/dadbod.lua`
  - [ ] Implement db browser, console, schema commands
  - [ ] Parse config/database.yml
  - [ ] Create tests
- [ ] LSP Integration
  - [ ] Create `lua/rails-tools/integrations/lsp.lua`
  - [ ] Enhance go-to-definition for Rails conventions
  - [ ] Add Rails-specific code actions
  - [ ] Create tests
- [ ] Telescope Integration (Enhanced)
  - [ ] Add schemas, migrations, helpers, fixtures pickers
  - [ ] Implement caching
  - [ ] Create tests
- [ ] Snippet Integration
  - [ ] Create `lua/rails-tools/integrations/snippets.lua`
  - [ ] Implement model, controller, migration, view templates
  - [ ] Support user customization
  - [ ] Create tests
- [ ] Test Integration (neotest)
  - [ ] Create `lua/rails-tools/integrations/neotest.lua`
  - [ ] Implement adapters for RSpec and Minitest
  - [ ] Create tests
- [ ] Completion Integration (nvim-cmp)
  - [ ] Create `lua/rails-tools/integrations/cmp.lua`
  - [ ] Implement context-aware completion
  - [ ] Create tests
- [ ] Add `config.integrations` section

---

## Configuration Reference

### Default Configuration Structure

```lua
{
  -- Module enable/disable
  modules = {
    -- Layer 3 - Phase 1 (default: true)
    alternate = true,
    finder = true,
    routes = true,
    console = true,
    runner = true,

    -- Layer 4 - Phase 2 (default: false)
    rspec = false,
    generators = false,
    grape = false,
    test_marker = false,
    gf = false,
    controller_view = false,

    -- Layer 5 - Phase 3 (default: false)
    schema = false,
    log_viewer = false,
    doctor = false,
    extractor = false,
    syntax = false,
  },

  -- Terminal settings (L1-013)
  terminal = {
    provider = "auto",  -- auto, toggleterm, native
    direction = "float",  -- float, horizontal, vertical
    float = { width = 0.8, height = 0.8 },
    horizontal = { size = 15 },
    vertical = { size = 80 },
  },

  -- Finder settings (L3-006)
  finder = {
    provider = "auto",  -- auto, telescope, native
    resources = { "models", "controllers", "views", "services", "policies", "jobs", "mailers", "serializers", "specs", "factories" },
    cache_ttl = 30,
  },

  -- Routes settings (L3-010)
  routes = {
    command = "bin/rails routes",
    args = "--expanded",
    cache_ttl = 300,
  },

  -- Console settings (L3-011)
  console = {
    command = "rails console",
  },

  -- Runner settings (L3-012)
  runner = {
    command = "rails runner",
  },

  -- Keymap settings (L3-009)
  keymaps = {
    enabled = true,
    prefix = "<leader>r",
  },

  -- Alternate file settings (L3-003)
  alternate = {
    custom_mappings = {},
  },

  -- View settings (L4-020)
  view = {
    engine = "auto",  -- auto, erb, haml, slim
    priority = { "erb", "haml", "slim" },
  },

  -- RSpec settings (L4-014)
  rspec = {
    command = "bundle exec rspec",
    save_last = true,
  },

  -- Syntax highlighting (L5-026)
  syntax = {
    enabled = true,
    associations = true,
    validations = true,
    callbacks = true,
    helpers = true,
    macros = true,
    custom_keywords = {},
  },

  -- Optional integrations (L5-027)
  integrations = {
    dadbod = { enabled = true },
    lsp = { enabled = true },
    telescope = { enabled = true, cached = true },
    snippets = { enabled = true },
    neotest = { enabled = true },
    cmp = { enabled = true },
  },
}
```

---

## Commands Reference

### Primary Command
- `:Rails` - Open central menu (L3-008)

### Subcommands
- `:Rails alternate` - Toggle alternate file (L3-003)
- `:Rails find {resource}` - Find resource by type (L3-006)
- `:Rails routes` - View routes (L3-010)
- `:Rails console` - Open Rails console (L3-011)
- `:Rails runner {code}` - Run code (L3-012)
- `:Rails runner` - Prompt for code (L3-012)
- `:Rails spec nearest` - Run nearest spec (L4-014)
- `:Rails spec file` - Run spec file (L4-014)
- `:Rails spec last` - Re-run last spec (L4-014)
- `:Rails generate {args}` - Run generator (L4-015)
- `:Rails grape routes` - View Grape routes (L4-017)
- `:Rails doctor` - Run diagnostics (L5-023)
- `:R [type]` - Jump to related file (L4-020)

### Telescope Commands
- `:Telescope rails models` (L3-007)
- `:Telescope rails controllers` (L3-007)
- `:Telescope rails views` (L3-007)
- `:Telescope rails services` (L3-007)
- `:Telescope rails specs` (L3-007)
- `:Telescope rails routes` (L3-007)
- `:Telescope rails grape` (L4-017)
- `:Telescope rails schemas` (L5-027)
- `:Telescope rails migrations` (L5-027)

### Health Check
- `:checkhealth rails-tools` (L2-005)

---

## Keymaps Reference

### Default Prefix: `<leader>r`

| Keymap | Action | Layer |
|--------|--------|-------|
| `<leader>rr` | Rails menu | L3-008 |
| `<leader>ra` | Alternate file | L3-003 |
| `<leader>rf` | Resource finder | L3-006 |
| `<leader>ro` | Routes navigator | L3-010 |
| `<leader>rc` | Console | L3-011 |
| `<leader>rx` | Runner prompt | L3-012 |
| `<leader>rg` | Generator | L4-015 |
| `<leader>rs` | Run nearest spec | L4-014 |
| `<leader>rS` | Run spec file | L4-014 |
| `<leader>rv` | Related view | L4-020 |

---

## File Structure (Target)

```
lua/rails-tools/
├── init.lua                  -- Entry point: setup() (L1-Entry)
├── config.lua                -- Default config + deep merge (L1-004)
├── commands.lua              -- :Rails command dispatcher (L1-Entry)
├── keymaps.lua               -- Keymap registration (L3-009)
├── utils.lua                 -- Shared utilities (L1-Entry)
├── cache.lua                 -- TTL cache (L1-Entry)
├── health.lua                -- :checkhealth rails-tools (L2-005)
├── detectors/                -- Auto-detection modules (L2)
│   ├── init.lua             -- Detector orchestrator (L2-001)
│   ├── rails.lua            -- Rails project detection (L2-001)
│   ├── test_framework.lua   -- RSpec vs Minitest (L2-002)
│   └── grape.lua            -- Grape API detection (L2-016)
├── core/                     -- Feature modules (L3, L4, L5)
│   ├── alternate.lua        -- Toggle impl ↔ spec (L3-003)
│   ├── finder.lua           -- Resource picker (L3-006)
│   ├── routes.lua           -- Parse and navigate routes (L3-010)
│   ├── console.lua          -- Rails console (L3-011)
│   ├── runner.lua           -- Rails runner (L3-012)
│   ├── generators.lua       -- Rails generators (L4-015)
│   ├── gf.lua               -- Context-aware gf (L4-019)
│   ├── controller_view.lua  -- Controller-View navigation (L4-020)
│   ├── schema.lua           -- Schema inspector (L5-021)
│   ├── log_viewer.lua       -- Log viewer (L5-022)
│   ├── doctor.lua           -- Rails doctor (L5-023)
│   ├── extractor.lua        -- Code extraction (L5-025)
│   └── syntax.lua           -- Syntax highlighting (L5-026)
├── integrations/             -- Test framework & optional integrations (L4, L5)
│   ├── rspec.lua            -- RSpec runner (L4-014)
│   ├── grape.lua            -- Grape support (L4-017)
│   ├── test_marker.lua      -- Test focus/unfocus (L4-018)
│   ├── detector.lua         -- Plugin detection (L5-027)
│   ├── manager.lua          -- Integration manager (L5-027)
│   ├── dadbod.lua           -- vim-dadbod integration (L5-027)
│   ├── lsp.lua              -- LSP integration (L5-027)
│   ├── snippets.lua         -- Snippet templates (L5-027)
│   ├── neotest.lua          -- neotest adapter (L5-027)
│   └── cmp.lua              -- nvim-cmp source (L5-027)
├── ui/
│   ├── menu.lua             -- :Rails central menu (L3-008)
│   └── terminal.lua         -- Terminal abstraction (L1-013)
└── telescope/
    └── init.lua             -- Telescope extension (L3-007)

plugin/
└── rails-tools.lua          -- Lazy-load registration (L1-Entry)

tests/                        -- mirrors lua/ structure
├── detectors/
├── core/
├── integrations/
└── ui/

doc/
└── rails-tools.txt          -- Vimdoc (L5-024)

syntax/
├── rails.vim                -- Main syntax (L5-026)
└── after/syntax/ruby/
    └── rails.vim            -- Ruby extension (L5-026)
```

---

## Notes

- All modules degrade gracefully if optional dependencies are missing
- Telescope is optional — falls back to vim.ui.select
- Toggleterm is optional — falls back to native terminal
- Phase 2+ modules are disabled by default
- Uses `vim.tbl_deep_extend("force", defaults, user_config)` for config merge
- All detectors cache their results for performance
- Cache is keyed by Rails root path
- Uses plenary.nvim test harness
- Minimum Neovim version: 0.9+

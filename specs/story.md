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
| Layer 1 - Infrastructure | 4 tasks | 4 | 100% |
| Layer 2 - Detection | 4 tasks | 4 | 100% |
| Layer 3 - Core Features | 8 tasks | 8 | 100% |
| Layer 4 - Enhanced | 6 tasks | 6 | 100% |
| Bug Fixes - Review | 11 tasks | 0 | 0% |
| Layer 5 - Polish | 4 tasks | 1 | 25% |
| Backlog - Experimental | 4 tasks | — | not scheduled |

### Completed Items ✅
- **L0-000** - Test Application (000-test-app.md)
- **L1-004** - Configuration System (001-config-system.md)
- **L1-013** - Terminal Abstraction Layer (002-terminal-abstraction.md)
- **L1-Entry** - Plugin Entry Points (029-plugin-entry-point.md)
- **L2-001** - Rails Detection (003-rails-detection.md)
- **L2-002** - Test Framework Detection (004-rspec-minitest-detection.md)
- **L2-005** - Health Check (005-health-check.md)
- **L2-016** - Grape API Detection (006-grape-api-detection.md)
- **L3-003** - Alternate File Navigation (007-alternate-file.md)
- **L3-006** - Resource Finder (008-resource-finder.md)
- **L3-007** - Telescope Integration (009-telescope-pickers.md)
- **L3-008** - Rails Menu (010-menu.md)
- **L3-009** - Keymap Registration (011-keymaps.md)
- **L3-010** - Routes Navigator (012-routes-navigator.md)
- **L3-011** - Rails Console (013-console.md)
- **L3-012** - Rails Runner (014-runner.md)
- **L4-014** - RSpec Runner (015-rspec-runner.md)
- **L4-015** - Rails Generators (016-generators.md)
- **L4-017** - Grape API Support (017-grape-support.md)
- **L4-018** - Test Marker (018-test-marker.md)
- **L4-019** - Context-Aware gf (019-context-aware-gf.md)
- **L4-020** - Controller-View Navigation (020-controller-view-navigation.md)
- **L5-021** - Schema Inspector: hover / `nvim-cmp` / `gd` for ActiveRecord columns (021-schema-inspector.md)

### Next Steps 📋 (In dependency order)
1. **Bug Fixes** - BF-054 + BF-055 → BF-061 → BF-056 → BF-057 → BF-058 → BF-059 + BF-060 → BF-062 → BF-063 + BF-064
2. **Phase 3** - Layer 5, next: Schema Display (L5-028)

---

## Layer 0 — Foundation

### L0-000. Test Application (000-test-app.md)
- [x] Create test Rails application at `test-app/`
- [x] Add models, controllers, views, specs
- [x] Add Grape API endpoints
- [x] Setup script for test environment

---

## Layer 1 — Core Infrastructure

**IMPORTANT**: This layer MUST be completed first. All other layers depend on it.

### L1-004. Configuration System (001-config-system.md) ✅ COMPLETE
- [x] Create `lua/rails-tools/config.lua`
- [x] Define `M.defaults` with all settings
- [x] Implement `M.setup(user_config)` with deep merge
- [x] Implement `M.get()` function
- [x] Support zero-config (nil config)
- [x] Create tests for config module
- [x] Default config includes:
  - [x] Module enable/disable (`schema` + opt-in Phase 2 modules only)
  - [x] Terminal settings (provider, direction, sizes)
  - [x] Finder settings (provider, resources, cache_ttl)
  - [x] Routes settings (command, args, cache_ttl)
  - [x] Console settings (command)
  - [x] Runner settings (command)
  - [x] Keymaps (enabled, prefix)
  - [x] Alternate file mappings (custom_mappings) ✅
  - [x] View engine detection
  - [x] RSpec settings

### L1-013. Terminal Abstraction Layer (002-terminal-abstraction.md) ✅ COMPLETE
- [x] Create `lua/rails-tools/ui/terminal.lua`
- [x] Implement `open(cmd, opts)`, `toggle()`, `send(text)` functions
- [x] Implement provider detection (auto, toggleterm, native)
- [x] Implement toggleterm backend
- [x] Implement native terminal backend
- [x] Support directions: float, horizontal, vertical
- [x] Configurable sizes: float (width, height), horizontal (rows), vertical (columns)
- [x] Create tests for terminal module
- [x] Test each provider and direction

### L1-Entry. Plugin Entry Points (029-plugin-entry-point.md)
- [x] Create `lua/rails-tools/init.lua` - Entry point with setup()
- [x] Create `lua/rails-tools/commands.lua` - Command dispatcher
- [x] Create `lua/rails-tools/utils.lua` - Shared utilities
- [x] Create `lua/rails-tools/cache.lua` - Shared cache (built ahead of
      schedule as part of 021-schema-inspector.md, since schema.lua needed
      it and it didn't exist yet)
- [x] Create `plugin/rails-tools.lua` - Lazy-load registration
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
  - [x] Monorepo opened at its top-level directory: features resolve the Rails root from the current file (console fixed to match finder/runner/routes)
  - [ ] Rails engine inside a host app: the engine has its own `Gemfile` + `bin/rails`, so its directory becomes the root and schema lookup misses the host's `db/schema.rb`
  - [ ] Projects that only have `db/structure.sql`: no schema columns (no crash)
  - [ ] Custom column types dumped as `t.column "name", "type"` show type `column` in hover
- [x] Create `tests/detectors/rails_spec.lua`

### L2-002. Test Framework Detection (004-rspec-minitest-detection.md)
- [x] Create `lua/rails-tools/detectors/test_framework.lua`
- [x] Implement `detect()`, `is_rspec()`, `is_minitest()` functions
- [x] Check spec/ directory → RSpec
- [x] Check test/ directory → Minitest
- [x] Handle projects with both directories
- [x] Create `tests/detectors/test_framework_spec.lua`

### L2-005. Health Check (005-health-check.md)
- [x] Create `lua/rails-tools/health.lua`
- [x] Implement `M.check()` function
- [x] Check Neovim version (>= 0.9)
- [x] Check Rails detection status
- [x] Check Ruby and Rails versions
- [x] Check optional dependencies (telescope, toggleterm, which-key)
- [x] Check project details (Gemfile, bin/rails, test framework, Grape)
- [x] Check module status (enabled/disabled)
- [x] Format output with vim.health API

### L2-016. Grape API Detection (006-grape-api-detection.md) [Phase 2]
- [x] Create `lua/rails-tools/detectors/grape.lua`
- [x] Implement `detect()` function
- [x] Check app/api/ directory existence
- [x] Check Gemfile for grape gem
- [x] Both conditions must be true
- [x] Create `tests/detectors/grape_spec.lua`

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
- [x] Handle nested namespaces (default `(.+)` mappings keep sub-directories; covered by `tests/core/alternate_spec.lua`)
- [x] Prompt to create file if alternate doesn't exist
- [x] Create `tests/core/alternate_spec.lua`

### L3-006. Resource Finder (008-resource-finder.md) ✅ COMPLETE
- [x] Create `lua/rails-tools/core/finder.lua`
- [x] Define resource_paths table
- [x] Implement `find(resource_type)` function
- [x] Implement directory scanning
- [x] Integrate with Telescope (when available)
- [x] Implement vim.ui.select fallback
- [x] Cache results with 30s TTL
- [x] Resources: models, controllers, views, services, policies, jobs, mailers, serializers, specs, factories
- [x] Create `tests/core/finder_spec.lua`

### L3-007. Telescope Integration (009-telescope-pickers.md) ✅ COMPLETE
- [x] Create `lua/rails-tools/telescope/init.lua`
- [x] Define exports table for Telescope registration
- [x] Implement pickers: one per `finder.resources` type, plus `rails` for all (routes picker moved to L3-010)
- [x] Add grape picker (placeholder for Phase 2)
- [x] Register extension (`lua/telescope/_extensions/rails.lua`, loaded from `setup()` when telescope.nvim is already loaded)
- [x] Gracefully handle missing telescope.nvim
- [x] Test each picker

### L3-008. Rails Menu (010-menu.md) ✅ COMPLETE
- [x] Create `lua/rails-tools/ui/menu.lua`
- [x] Implement `M.open()` function
- [x] Define menu items table
- [x] Filter items based on enabled modules — done in L4-014 (first gated item)
- [x] Always show: Alternate File, Find Resource (plus Open Console, Run Code: Phase 1, always on)
- [ ] Conditional items based on module config — added by L3-010, L4-014, L4-015, L4-017
- [x] Register `:Rails` command in commands.lua
- [x] Create `:Rails` command dispatch (`:Rails` with no subcommand opens the menu)

### L3-009. Keymap Registration (011-keymaps.md) ✅ COMPLETE
- [x] Create `lua/rails-tools/keymaps.lua`
- [x] Implement `M.setup()` function
- [x] Define default keymap bindings
- [x] Support configurable prefix (default: `<leader>r`)
- [x] Check `config.keymaps.enabled` before registering
- [x] Keymaps:
  - [x] `<leader>rr` - Rails menu
  - [x] `<leader>ra` - Alternate file
  - [x] `<leader>rf` - Resource finder
  - [x] `<leader>ro` - Routes navigator — moved to L3-010, done there
  - [x] `<leader>rc` - Console
  - [x] `<leader>rx` - Runner
- [x] Create tests for keymap registration

### L3-010. Routes Navigator (012-routes-navigator.md) ✅ COMPLETE
- [x] Create `lua/rails-tools/core/routes.lua`
- [x] Implement `show()`, `refresh()`, `goto_action()` functions
- [x] Implement async shell command runner (vim.fn.jobstart)
- [x] Parse `bin/rails routes --expanded` output
- [x] Parse controller#action → file and method
- [x] Implement method line finder
- [x] Integrate with cache.lua (from L1-Entry)
- [x] Cache with TTL from config (default 300s)
- [x] Handle namespaced routes
- [x] Show loading indicator
- [x] Telescope `routes` picker in `lua/rails-tools/telescope/init.lua` (moved from L3-007)
- [x] Force refresh with `:Rails routes!`
- [x] Add "View Routes" item to `ui/menu.lua` (moved from L3-008)
- [x] Register keymap `<leader>ro` in `keymaps.lua` (moved from L3-009)
- [x] Create `tests/core/routes_spec.lua`

### L3-011. Rails Console (013-console.md)
- [x] Create `lua/rails-tools/core/console.lua`
- [x] Implement `open()`, `toggle()` functions
- [x] Integrate with ui/terminal.lua (from L1-013)
- [x] Read `config.console.command`
- [x] Register `:Rails console` subcommand
- [x] Create tests for console module

### L3-012. Rails Runner (014-runner.md)
- [x] Create `lua/rails-tools/core/runner.lua`
- [x] Implement `run(code)`, `run_prompt()`, `run_visual()` functions
- [x] Integrate with ui/terminal.lua (from L1-013)
- [x] Read `config.runner.command`
- [x] Register `:Rails runner {code}` subcommands
- [x] Create tests for runner module

---

## Layer 4 — Enhanced Navigation (Phase 2)

**Depends on**: Layer 3 (Core Features)

### L4-014. RSpec Runner (015-rspec-runner.md)
- [x] Create `lua/rails-tools/integrations/rspec.lua`
- [x] Implement `run_nearest()`, `run_file()`, `run_last()` functions
- [x] Display test results
- [x] Handle test failures
- [x] Cache last executed spec
- [x] Register commands: `:Rails spec nearest`, `:Rails spec file`, `:Rails spec last`
- [x] Register keymaps: `<leader>rs`, `<leader>rS`
- [x] Add "Run Nearest Spec" / "Run Spec File" items to `ui/menu.lua`, shown only when `modules.rspec = true`; add the menu's filtering by `config.modules` (moved from L3-008)
- [x] Only active when `modules.rspec = true`
- [x] Create tests for RSpec runner

### L4-015. Rails Generators (016-generators.md)
- [x] Create `lua/rails-tools/core/generators.lua`
- [x] Implement `run(args)` function
- [x] Support model, controller, migration generation
- [x] Display generator output
- [x] Register `:Rails generate {args}` command
- [x] Register keymap: `<leader>rg`
- [x] Add "Run Generator" item to `ui/menu.lua`, shown only when `modules.generators = true` (moved from L3-008)
- [x] Only active when `modules.generators = true`
- [x] Create `tests/core/generators_spec.lua`

### L4-017. Grape API Support (017-grape-support.md)
- [x] Create `lua/rails-tools/integrations/grape.lua`
- [x] Implement Grape routes parser (lists the Grape APIs mounted in the Rails routes with `runner.command`)
- [x] Implement endpoint finder
- [x] Display Grape endpoints in picker
- [x] Register `:Rails grape routes` command (`:Rails grape routes!` refreshes the cache)
- [x] Integrate with Telescope
- [x] Add "Grape Endpoints" item to `ui/menu.lua`, shown only when `modules.grape = true` (moved from L3-008)
- [x] Only active when `modules.grape = true`
- [x] Create `tests/integrations/grape_spec.lua`

### L4-018. Test Marker (018-test-marker.md)
- [x] Create `lua/rails-tools/integrations/test_marker.lua`
- [x] Implement `is_focused()`, `focus()`, `unfocus()`, `toggle()` functions
- [x] Support RSpec syntax (fit, fdescribe, fcontext)
- [x] Only active when `modules.test_marker = true`
- [x] Create tests for test marker

### L4-019. Context-Aware gf (019-context-aware-gf.md)
- [x] Create `lua/rails-tools/core/gf.lua`
- [x] Implement context detection (regex on the current line; Treesitter dropped at spec review)
- [x] Implement partial path parser: `"shared/header"` → `app/views/shared/_header.html.erb`
- [x] Implement fixture finder: `fixtures :users` / `users(:alice)` → `test/fixtures/users.yml`
- [x] Implement table → model finder in migrations: cursor on a table symbol/string
      (`create_table :course_progresses`, `change_table`, `add_column :users, ...`)
      → `app/models/course_progress.rb`; `t.references :enrollment` → `app/models/enrollment.rb`.
      Prefer the annotate `# Table name:` mapping (custom `self.table_name`), else singularize + camelize
- [x] Implement route finder: route name → controller#action
- [x] Support visual selection for complex paths
- [x] Detect view engine: .erb, .haml, .slim
- [x] Detect format: .html, .json, .xml
- [x] Fallback to default `gf` if no Rails context
- [x] Only active when `modules.gf = true`
- [x] Create `tests/core/gf_spec.lua`
- Removed at spec review: migration finder `User` → latest `*_create_users.rb`
  (constant → file is 030; model → migration is a related file in L4-020)

### L4-020. Controller-View Navigation (020-controller-view-navigation.md)
- [x] Create `lua/rails-tools/core/controller_view.lua`
- [x] Implement `to_view()` - Controller action → View
- [x] Implement `views_for_controller()` - List all views
- [x] Implement `from_view()` - View → Controller
- [x] Implement related files: helper, schema, layout, fixture, migration
- [x] Implement `from_migration()` - Migration → model of the table it creates/changes
      (first `create_table` / `change_table` / `add_column` table in the file), listed in `related_menu()`
- [x] Implement `related_menu()` - Show available related files
- [x] Register `:Rails related [type]` command (`:R` dropped at spec review: all subcommands go through `:Rails`)
- [x] Register keymap: `<leader>rv`
- [x] Smart view engine detection (.erb, .haml, .slim)
- [x] Smart format detection (.html, .json, .xml)
- [x] Handle namespaced controllers
- [x] Prompt to create missing views
- [x] Only active when `modules.controller_view = true`
- [x] Create `tests/core/controller_view_spec.lua`

---

## Bug Fixes — Review Findings

**Depends on**: nothing new; fixes for Layers 1–5. Do these before the remaining Layer 5 tasks, in the order below.
Each task links its GitHub issue, which holds the evidence and full acceptance criteria.

### BF-054. Module gating for schema and Telescope grape (GitHub #54)
- [x] `modules.schema = false` skips schema cache autocmd, LSP `K`/`gd` override and cmp source
- [x] `modules.grape = false` hides or blocks the Telescope `grape` picker
- [x] Regression tests for both flags

### BF-055. setup() can be retried after a failed sub-module (GitHub #55)
- [x] Mark setup done only after every sub-module setup succeeds
- [x] A second `setup()` after success is still a no-op
- [x] Regression test: failing sub-module, then a successful retry

### BF-061. singularize/pluralize irregular and uncountable words (GitHub #61)
- [x] Irregular table (person, child, man, woman, mouse, ox)
- [x] Uncountables (equipment, information, series, species, news)
- [x] Keep `movie`-type words correct for the `-ies` rule
- [x] Unit tests for each pair in both directions

### BF-056. Namespaced models and `&.` receivers (GitHub #56)
- [x] `model_for_path` returns `Admin::User` for `app/models/admin/user.rb`
- [x] `annotate.scan` keys models by full namespaced name
- [x] Decide and document how `app/models/concerns/**` is handled
- [x] `user&.email` resolves receiver `user` for hover, `gd` and completion
- [x] Regression tests with a namespaced fixture and a `&.` case

### BF-057. Schema columns for models without an annotate block (GitHub #57)
- [ ] Infer the table name from the model name; `self.table_name = "..."` wins when present
- [ ] Columns come from `db/schema.rb`, `gd` jumps to the schema line
- [ ] Annotated models unchanged
- [ ] Regression test with an un-annotated model fixture

### BF-058. Detector cache invalidation (GitHub #58)
- [x] Do not cache negative results forever (re-check on `DirChanged` or after a TTL)
- [x] Public, documented way to clear detector caches
- [x] Regression test: detect in empty dir, add `Gemfile` + `bin/rails`, detect again

### BF-059. Opt-out and custom keys for the LSP `K`/`gd` override (GitHub #59)
- [ ] Config option to disable the override or choose the keys
- [ ] Keep an existing user buffer mapping, or document the chosen behaviour
- [ ] Expose Rails-aware hover/definition as functions users can map
- [ ] Regression tests for enabled, disabled and custom-key cases

### BF-060. One Rails executable for all default commands (GitHub #60)
- [x] Console, runner, generators and routes use the same executable, preferring `bin/rails`
- [x] User-set commands are never changed
- [x] README/docs updated

### BF-062. Test marker with multi-line `it(` and heredocs (GitHub #62)
- [x] Cursor inside a multi-line `it(...) do` focuses the `it` line
- [x] A heredoc with a dedented `end` does not break the search
- [x] Both cases added as regression tests

### BF-063. Terminal leaves the finished command's window behind (GitHub #63)
- [x] Next command reuses or closes the previous terminal window and buffer (native and toggleterm)
- [x] `toggle` / `show` work on a terminal whose process has exited
- [x] `confirm_replace` asks only when a job is running
- [x] Regression test from the reproduce script in the issue

### BF-064. `cmp.dedupe_with_lsp` matching and Neovim 0.9 support (GitHub #64)
- [x] Check each configured client name separately
- [x] Fall back to `get_active_clients` on Neovim 0.9
- [x] Tests use a real dummy LSP client instead of replacing `vim.lsp.get_clients`

---

## Layer 5 — Polish & Integrations (Phase 3)

**Depends on**: Layer 4 (Enhanced Navigation)

### L5-021. Schema Inspector (021-schema-inspector.md)
- [x] Create `lua/rails-tools/core/schema.lua`
- [x] Parse `db/schema.rb` (columns, types, indexes)
- [x] Parse `annotate` gem blocks in `app/models/**/*.rb` and merge with `db/schema.rb`
- [x] Integrate with cache.lua, invalidate on save
- [x] Hover (`K`) and go-to-definition (`gd`) for ActiveRecord columns
- [x] `nvim-cmp` completion source for ActiveRecord columns
- [x] Create `tests/core/schema_spec.lua`

### L5-028. Schema Display (028-schema-display.md)
- [ ] `:Rails schema {table}` shows columns, types, indexes
- [ ] Telescope picker for tables

### L5-024. Documentation (024-documentation.md)
- [ ] Complete README.md with all features
- [ ] Complete doc/rails-tools.txt (Vimdoc)
- [ ] Document all commands
- [ ] Document all keymaps
- [ ] Provide usage examples
- [ ] Create migration guide
- [ ] Review documentation completeness

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
- [ ] Add a `config.integrations` entry per integration as it ships

---

## Backlog — Experimental (not scheduled)

Out of the current roadmap to keep scope on navigation, execution and
schema-aware editing. Revisit only after Layers 1–5 ship.

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

### Idea: All modules enabled by default (no number yet)
Today `modules.rspec`, `generators`, `grape`, `test_marker`, `gf` and `controller_view` default to `false` (`config.lua` defaults); only `schema` is on. Flip them so a zero-config install gets every feature, each still switchable off.
- [ ] Default every `modules.*` flag to `true`
- [ ] A module that needs a missing optional dependency or project type (telescope, toggleterm, no Grape) skips quietly, no error
- [ ] User `modules.<name> = false` still disables it
- [ ] Update README, `Configuration Reference` below and the Phase 2 note in `CLAUDE.md` ("disabled by default")
- [ ] Tests: defaults are all `true`; `false` override still works

### Idea: Center the cursor after jumps (no number yet)
After a jump to a file or definition (`gf`, alternate, resource finder, routes, controller-view, LSP `gd`), recenter the window with `zz`. Only `integrations/lsp.lua:85` does this today.
- [ ] New option, default on (e.g. `jump.center = true`), `false` turns it off
- [ ] One shared helper used by every jump path, not a `zz` per call site
- [ ] Skip the recenter when the target is already visible, if that keeps the view from jumping needlessly (decide in the spec)
- [ ] Tests for enabled and disabled

---

## Configuration Reference

### Default Configuration Structure

```lua
{
  -- Only features that may need turning off. Phase 1 features are always on.
  modules = {
    schema = true,  -- L5-021 / L5-028

    -- Phase 2, opt-in
    rspec = false,
    generators = false,
    grape = false,
    test_marker = false,
    gf = false,
    controller_view = false,
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
    resources = {
      models = { paths = { "app/models" } },
      controllers = { paths = { "app/controllers" } },
      views = { paths = { "app/views" } },
      services = { paths = { "app/services" } },
      policies = { paths = { "app/policies" } },
      jobs = { paths = { "app/jobs" } },
      mailers = { paths = { "app/mailers" } },
      serializers = { paths = { "app/serializers" } },
      specs = { paths = { "spec", "test" } },
      factories = { paths = { "spec/factories", "test/factories" } },
    },
    cache_ttl = 30,
  },

  -- command for routes/console/runner/generators: not set by default; built at run time as bin/rails <subcommand> (script/rails when the app has no bin/rails)
  -- Routes settings (L3-010)
  routes = {
    args = "--expanded",
    cache_ttl = 300,
  },

  -- Console settings (L3-011)
  console = {},

  -- Runner settings (L3-012)
  runner = {},

  -- Generator settings (L4-015)
  generators = {},

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

  -- nvim-cmp source (L5-021)
  cmp = {
    dedupe_with_lsp = {},  -- LSP client names that already complete columns, e.g. { "ruby_lsp" }
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
- `:Rails doctor` - Run diagnostics (L5-023, backlog)
- `:Rails related [type]` - Jump to related file (L4-020)

### Telescope Commands
- `:Telescope rails models` (L3-007)
- `:Telescope rails controllers` (L3-007)
- `:Telescope rails views` (L3-007)
- `:Telescope rails services` (L3-007)
- `:Telescope rails specs` (L3-007)
- `:Telescope rails routes` (L3-010)
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

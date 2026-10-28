# Implement plan — L1-004 Configuration System

Source specs: `specs/issues/001-config-system.md`, `specs/story.md` (section "Default Configuration Structure" is the source of truth for default values).

## Goal
Finish `lua/rails-tools/config.lua`: complete `M.defaults` and add `tests/config_spec.lua`. `setup()`, `get()`, deep merge and zero-config already work — do not rewrite them.

## Scope
Only these two files:
- Edit `lua/rails-tools/config.lua` — `M.defaults` only.
- Create `tests/config_spec.lua`.
- Then tick the L1-004 boxes in `specs/story.md` and `specs/issues/001-config-system.md`.

## Do NOT touch
- `built_in_mappings`, `M.alternate_mappings`, `M.setup`, `M.get`.
- Existing keys already in `M.defaults` (`terminal.provider`, `terminal.direction`, `keymaps`, `alternate`, `cmp`) keep their current values.
- No comments in code (project rule). Keep LuaDoc annotations as they are.
- No new files in `lua/`. Do not wire any key into other modules (nothing reads the new keys yet).

## Step 1 — Complete `M.defaults`
Target value (from story):

```lua
M.defaults = {
  modules = {
    schema = true,
    rspec = false,
    generators = false,
    grape = false,
    test_marker = false,
    gf = false,
    controller_view = false,
  },
  terminal = {
    provider = "auto",
    direction = "float",
    float = { width = 0.8, height = 0.8 },
    horizontal = { size = 15 },
    vertical = { size = 80 },
  },
  finder = {
    provider = "auto",
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
  routes = {
    command = "bin/rails routes",
    args = "--expanded",
    cache_ttl = 300,
  },
  console = { command = "rails console" },
  runner = { command = "rails runner" },
  keymaps = { enabled = true, prefix = "<leader>r" },
  alternate = { custom_mappings = {} },
  view = {
    engine = "auto",
    priority = { "erb", "haml", "slim" },
  },
  rspec = {
    command = "bundle exec rspec",
    save_last = true,
  },
  cmp = { dedupe_with_lsp = {} },
}
```

Match the existing multi-line formatting style of the file when writing it (one key per line); the block above is compact only for readability.

New keys vs current file: `modules.schema/test_marker/gf/controller_view`, `terminal.float/horizontal/vertical`, `finder`, `routes`, `console`, `runner`, `view`, `rspec`.

## Step 2 — Create `tests/config_spec.lua`
Use plenary `describe/it` (same style as `tests/init_spec.lua`). The module keeps state in a file-local `current`, so in `before_each` reset it with `package.loaded["rails-tools.config"] = nil` and re-`require`.

Cases (each maps to an acceptance criterion):
1. `setup()` with nil returns defaults (zero-config).
2. `get()` before any `setup()` returns defaults.
3. `setup()` return value equals what `get()` returns afterwards.
4. Partial override: `setup({ keymaps = { prefix = "<leader>x" } })` → `keymaps.prefix == "<leader>x"` and `keymaps.enabled == true` (deep merge keeps siblings).
5. Module toggle: `setup({ modules = { rspec = true } })` → `modules.rspec == true`, `modules.schema == true`, `modules.generators == false`.
6. Terminal override: `setup({ terminal = { direction = "horizontal", horizontal = { size = 20 } } })` → those change, `terminal.provider == "auto"` and `terminal.float.width == 0.8` stay.
7. Finder override: override `finder.cache_ttl` and one `finder.resources.models.paths`; other resources unchanged.
8. Routes override: `setup({ routes = { cache_ttl = 60 } })` → `cache_ttl == 60`, `command == "bin/rails routes"`.
9. Defaults contain every top-level key: `modules, terminal, finder, routes, console, runner, keymaps, alternate, view, rspec, cmp`.
10. `setup()` does not mutate `M.defaults`: after `setup({ keymaps = { prefix = "<leader>x" } })`, `config.defaults.keymaps.prefix == "<leader>r"`.
11. Custom alternate mappings: `setup({ alternate = { custom_mappings = { { from = "^a$", to = "b" } } } })` → `alternate_mappings("rspec")[1]` is `{ from = "^a$", to = "b" }` and the built-in rspec mappings follow it.
12. `alternate_mappings` accepts `pattern`/`target` aliases: `{ pattern = "^a$", target = "b" }` → `{ from = "^a$", to = "b" }`.

Do not weaken or edit any existing test file.

## Step 3 — Verify
```bash
make test-file FILE=tests/config_spec.lua
make test
make lint
```
All must pass. Existing tests (`tests/init_spec.lua`, `tests/integrations/cmp_spec.lua`, `tests/core/alternate_spec.lua`) must stay green with no edits.

## Step 4 — Update checkboxes
- `specs/story.md` L1-004: tick every item. Remove the L1-004 line from "In Progress", move it to "Completed Items", update the Layer 1 progress row (2 → 3 of 4 tasks, 75%). Remove "Complete L1-004" from "Next Steps" and renumber.
- `specs/issues/001-config-system.md`: tick all Acceptance Criteria and Implementation Checklist items.

## Notes / risks
- `specs/issues/001-config-system.md` Notes say "Default modules: alternate, finder, routes, console, runner enabled" — this conflicts with `specs/story.md`, which says Phase 1 features are always on and `modules` only holds things that can be turned off. This plan follows the story. Do not add `modules.alternate/finder/routes/console/runner`.
- `modules.schema = true` is added to defaults, but `lua/rails-tools/core/schema.lua` does not read it yet (checked: no `modules.` access in `lua/`). Out of scope here; do not add gating.
- The story's "Module enable/disable" line lists `schema` + opt-in Phase 2 modules; `gf` and `controller_view` are included because the story's config reference includes them.

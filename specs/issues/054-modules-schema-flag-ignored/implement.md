# Implement plan — BF-054 Module gating for schema and Telescope grape

Review: Approved

## Decisions made without you
- Gate schema in `init.lua` only, not inside each module.
- Telescope grape: warn when run, do not hide the export.
- README is not changed.

Source: `specs/issues/054-modules-schema-flag-ignored/issue.md` (GitHub #54), `specs/story.md` (BF-054).

## Description
- `modules.schema` (default `true`, `config.lua:42`) has no reader. `setup()` always calls `core.schema.setup()`, `integrations.lsp.setup()` and `integrations.cmp.setup()` (`init.lua:21,23,24`), so `modules.schema = false` still creates the `rails_tools_schema_cache` and `rails_tools_lsp_schema` augroups, remaps `K`/`gd` on LspAttach and registers the `rails_schema` cmp source.
- `modules.grape` defaults to `false` (`config.lua:45`). `:Rails grape` warns when it is off (`commands.lua:39-41`), but the Telescope `grape` picker (`telescope/init.lua:31-33`) runs anyway. With the default config, `:Telescope rails grape` opens the Grape picker even though Grape support is off.

## Design
- Schema: gate the three calls in `init.lua` `M.setup()` on `config.get().modules.schema`. Nothing else calls these three `setup()` functions (only `init.lua`, plus direct calls in their own tests), so one check covers every entry point.
  - The `gf` call sits between them (`init.lua:22`) and stays where it is; read the flag once into a local and use two `if` blocks, so the `gf` line does not move.
  - Not inside each module (the `gf.lua:456` pattern): that needs three edits, and the existing doc comments of those three `setup()` functions would then be incomplete, which we may not rewrite without approval.
- Telescope grape: check `modules.grape` when the picker runs, inside `exports.grape`, and show the same warning as `:Rails grape`: `"Rails: Grape support is disabled, set modules.grape = true"` (WARN), then return.
  - Not "do not export": `M.exports` is built once when `rails-tools.telescope` is first required (`telescope/init.lua:41`), and `telescope/_extensions/rails.lua` can require it before the user's `setup()` runs. The picker would then be hidden even after the user enables Grape. Checking at call time avoids that and matches `:Rails grape`.
- No config, menu, keymap, health or README change.

## Acceptance Criteria
- [ ] `setup({ modules = { schema = false } })`: no `rails_tools_schema_cache` and no `rails_tools_lsp_schema` augroup exist, so `K`/`gd` are never remapped (checked through the absent LspAttach augroup, the only place they are mapped); `cmp.register_source` is not called.
- [ ] `setup()` with defaults: both augroups exist and `rails_schema` is registered (unchanged).
- [ ] `modules.grape = false` (default): `require("rails-tools.telescope").exports.grape()` warns `"Rails: Grape support is disabled, set modules.grape = true"` and does not call `integrations.grape.show`.
- [ ] `modules.grape = true`: the picker opens as before.
- [ ] `make test` and `make lint` pass.

## Implementation Checklist
1. `lua/rails-tools/init.lua` `M.setup()`: replace lines 21-24 with
   ```lua
   local schema_enabled = config.get().modules.schema
   if schema_enabled then
     require("rails-tools.core.schema").setup()
   end
   require("rails-tools.core.gf").setup()
   if schema_enabled then
     require("rails-tools.integrations.lsp").setup()
     require("rails-tools.integrations.cmp").setup()
   end
   ```
   No other change in the file.
2. `lua/rails-tools/telescope/init.lua` `exports.grape`: before the `show` call, add
   ```lua
   if not config.get().modules.grape then
     vim.notify("Rails: Grape support is disabled, set modules.grape = true", vim.log.levels.WARN)
     return
   end
   ```
   (`config` is already required at the top of the file.)
3. `tests/init_spec.lua`, new `describe("modules.schema", ...)` inside the existing `describe`:
   - `before_each`: `pcall(vim.api.nvim_del_augroup_by_name, "rails_tools_schema_cache")`, same for `"rails_tools_lsp_schema"` (earlier tests in this file already ran `setup()` with defaults); stub `package.loaded["cmp"] = { register_source = function(name) table.insert(registered_sources, name) end }` with `registered_sources = {}`. The outer `before_each` already clears `rails-tools.integrations.cmp`, so its `registered` flag resets.
   - `after_each`: `package.loaded["cmp"] = nil`.
   - `it("skips the schema cache, LSP override and cmp source when modules.schema is false")`: `setup({ modules = { schema = false } })`; assert `vim.fn.exists("#rails_tools_schema_cache") == 0`, `vim.fn.exists("#rails_tools_lsp_schema") == 0`, `registered_sources` is empty.
   - `it("sets up the schema cache, LSP override and cmp source by default")`: `setup()`; assert both `exists(...) == 1` and `registered_sources` equals `{ "rails_schema" }`.
4. `tests/telescope/init_spec.lua`:
   - Existing test `"grape opens the Grape endpoints picker with Telescope and the picker options"`: add `require("rails-tools.config").setup({ modules = { grape = true } })` as its first line. Needed because the default is now blocked; the assertions stay the same.
   - New `it("grape warns and does nothing when modules.grape is false")`: call `exports.grape({})` with default config; assert `grape_show_calls` is empty, one notification with msg `"Rails: Grape support is disabled, set modules.grape = true"` and level `vim.log.levels.WARN`.
5. Run `make test` and `make lint`.
6. Tick BF-054 items in `specs/story.md` and the acceptance criteria in `issue.md`.

## Notes
- Do NOT touch: `config.lua`, `core/schema.lua`, `integrations/lsp.lua`, `integrations/cmp.lua`, `commands.lua`, `ui/menu.lua`, `keymaps.lua`, `health.lua`, README. No new comments.
- Test changed (intended spec change): the existing Telescope grape test now enables `modules.grape` first. No assertion is weakened.
- `vim.fn.exists("#group")` returns 0 for an augroup that does not exist, so the test does not depend on `nvim_get_autocmds` error behaviour.
- Plenary `test_directory` runs each spec file in its own Neovim, so augroups from other files do not leak into `init_spec.lua`; only the earlier tests in the same file do, which step 3 handles.
- A user who calls `require("rails-tools.integrations.cmp").setup()` themselves bypasses the flag. The README does not document that call; accepted.
- `:Telescope rails grape` stays listed in Telescope completion when Grape is off; it only warns when run, the same way `:Rails grape` stays callable and warns.
- BF-055 (#55) also edits `init.lua` `M.setup()`. Whichever merges second rebases, then reruns `tests/init_spec.lua`.

# Implement plan — BF-055 setup() can be retried after a failed sub-module

Source specs: `specs/issues/055-setup-done-flag-blocks-retry/issue.md` (GitHub #55), `specs/story.md` (BF-055).

## Goal
If a sub-module throws during `setup()`, a later `setup()` call runs again instead of returning early. After one successful `setup()`, later calls stay a no-op.

## Scope
- `lua/rails-tools/init.lua`: move `setup_done = true` from before the sub-module calls to after the last one (`require("rails-tools.telescope").setup()`).
- `tests/init_spec.lua`: add regression tests (file already holds the `rails-tools.init` specs).
- Tick BF-055 in `specs/story.md` and the acceptance criteria in `issue.md`.

## Do NOT touch
- Sub-module `setup()` functions (`config`, `commands`, `keymaps`, `core/schema`, `core/gf`, `integrations/lsp`, `integrations/cmp`, `telescope`).
- `health.lua` (see Risks).
- No `pcall`, no error reporting wrapper, no new comments. Keep the existing LuaDoc on `M.setup`.

## Design
- Current code (`init.lua:12-15`) sets `setup_done = true` before `config.setup(opts)`. Any error in a later call leaves the flag true, so every retry returns at line 12.
- New order: check flag → run all sub-module setups → set `setup_done = true`.
- An error from a sub-module propagates to the caller unchanged (Lua error from `require("rails-tools").setup()`; the plugin manager or `:lua` shows it). The flag stays `false`, so a fixed config or a second call runs everything again.
- Why no `pcall` wrapper: the error is already reported by Lua's normal propagation; a wrapper that resets the flag and rethrows gives the same result with more code and loses nothing by being skipped.

## Retry safety of sub-modules (verified by reading code)
A retry re-runs every sub-module before the one that failed. Each is safe to run twice:
- `config.setup` (`config.lua:139-142`): rebuilds `current` from defaults + opts; no side effect beyond overwriting.
- `commands.setup` (`commands.lua:128-158`): guarded by its own `registered` flag; `:Rails` is created once.
- `keymaps.setup` (`keymaps.lua:76-91`): `vim.keymap.set` overwrites the same lhs; no duplicates.
- `core/schema.setup` (`core/schema.lua:158-169`): autocmd in augroup `rails_tools_schema_cache` with `clear = true`; re-run replaces it.
- `core/gf.setup` (`core/gf.lua:455-473`): augroup `rails_tools_gf` with `clear = true`; it also calls `attach(bufnr)` on loaded buffers again; `attach` (`core/gf.lua:448-451`) only sets buffer-local `gf` maps with `vim.keymap.set`, so a second call overwrites.
- `integrations/lsp.setup` (`integrations/lsp.lua:97-116`): augroup `rails_tools_lsp_schema` with `clear = true`.
- `integrations/cmp.setup` (`integrations/cmp.lua:91-102`): guarded by its own `registered` flag.
- `telescope.setup` (`telescope/init.lua:44-55`): last in the list and wraps `load_extension` in `pcall`, so it never throws; it can only run twice if setup had already succeeded, which the flag blocks. No double-run case.

## Implementation Checklist
1. `lua/rails-tools/init.lua`: delete the line `setup_done = true` after the early-return block; add `setup_done = true` as the last line of `M.setup`, after `require("rails-tools.telescope").setup()`.
2. `tests/init_spec.lua`: inside the existing `describe("rails-tools.init", ...)` add:
   - `after_each` that sets `package.loaded["rails-tools.core.gf"] = nil` (so the stub below does not leak into other tests).
   - `it("setup() runs again after a sub-module error", ...)`:
     - `local gf_setup_calls = 0`
     - `package.loaded["rails-tools.core.gf"] = { setup = function() gf_setup_calls = gf_setup_calls + 1; error("forced gf failure") end }`
     - `local rails_tools = require("rails-tools")`
     - `assert.has.errors(function() rails_tools.setup() end)`
     - replace the stub with `{ setup = function() gf_setup_calls = gf_setup_calls + 1 end }`
     - `assert.has_no.errors(function() rails_tools.setup() end)`
     - `assert.are.equal(2, gf_setup_calls)`
     - after the retry, assert exactly 1 autocmd in group `rails_tools_schema_cache` and exactly 1 in `rails_tools_lsp_schema` (`vim.api.nvim_get_autocmds({ group = ... })`), proving the retry leaves no duplicates
   - `it("setup() is a no-op after a successful run", ...)`:
     - stub `package.loaded["rails-tools.core.gf"] = { setup = function() gf_setup_calls = gf_setup_calls + 1 end }`
     - call `rails_tools.setup()` twice
     - `assert.are.equal(1, gf_setup_calls)`
   - `before_each` already clears `package.loaded["rails-tools"]`, so each test gets a fresh `setup_done = false`.
3. Run `make test-file FILE=tests/init_spec.lua`, then `make test` and `make lint`. All green.
4. Confirm the new failure test fails on the old `init.lua` (flag set first → second `setup()` returns early → `gf_setup_calls == 1`).
5. Tick BF-055 items in `specs/story.md` and the acceptance criteria in `specs/issues/055-setup-done-flag-blocks-retry/issue.md`.

## Acceptance Criteria
- [ ] `setup_done` is set only after every sub-module `setup()` returns without error.
- [ ] A sub-module error propagates out of `setup()` unchanged and a later `setup()` runs all sub-modules again.
- [ ] A second `setup()` after a successful one runs no sub-module.
- [ ] Regression tests in `tests/init_spec.lua` pass; the failure test fails on the old code.
- [ ] `make test` and `make lint` pass.

## Decisions
- Fix approach: set the flag after the last sub-module call, no `pcall` wrapper. Reason: minimal change, error is still reported by normal propagation, all re-run sub-modules are retry-safe (see above).
- Failure reporting: rely on the Lua error reaching the caller; no extra `vim.notify`. Reason: the issue accepts either; adding a notify changes behaviour beyond the bug.
- Module forced to fail in the test: `rails-tools.core.gf`, stubbed via `package.loaded`. Reason: `init.lua` requires it lazily inside `setup()`, so the stub is picked up; it sits in the middle of the list, so the test also exercises re-running earlier modules (`config`, `commands`, `keymaps`, `schema`).
- Reviewer finding accepted: add the duplicate-autocmd assertions above to the retry test (cheap, covers the retry-safety claim).
- Test location: `tests/init_spec.lua` (existing spec for this module), not a new file.

## Risks
- Retry with a changed `keymaps.prefix` leaves the old prefix mappings from the failed run. Reachable only if the user edits config and calls `setup()` again in the same session; low impact, out of scope.
- Pre-existing, unrelated to this change: `:checkhealth` reports "setup() called" when `:Rails` exists, so a setup that failed after `commands.setup` still shows OK.
- Retry with edited config can leave stale setup from the failed run (`modules.gf=false` keeps the gf augroup and maps, `keymaps.enabled=false` keeps old maps). Same-session retry with edited config only; low impact, out of scope.
- A retry with no opts resets config to defaults (`config.setup` rebuilds from defaults + opts). Could not happen before because a retry did nothing; low impact.
- Merge order with BF-054: both edit `M.setup` in `init.lua` and `tests/init_spec.lua`. Whichever merges second keeps `setup_done = true` after the last gated block and keeps the `after_each` that clears the gf stub.
- If another module ever calls `require("rails-tools").setup()` from inside a sub-module setup, the late flag would allow recursion. Checked: no such call exists in `lua/` today.

Review: Approved

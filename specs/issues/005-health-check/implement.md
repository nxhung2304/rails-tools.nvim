# Implement plan — L2-005 Health Check

Source specs: `specs/issues/005-health-check.md`, `specs/story.md` (L2-005).

## Goal
Create `lua/rails-tools/health.lua` so `:checkhealth rails-tools` reports the Neovim version, Rails project detection, Ruby/Rails versions, project files, optional dependencies and module status.

## Scope
- Create `lua/rails-tools/health.lua`.
- Create `tests/health_spec.lua`.
- Tick L2-005 in `specs/story.md` and `specs/issues/005-health-check.md`; also fix the stale L1-013 / L1-Entry status in `specs/story.md` (both already merged: PR #35, PR #31).

## Do NOT touch
- `config.lua`, `commands.lua`, `init.lua`, detectors: health only reads them.
- Existing tests.
- No new comments in code. LuaDoc on the public `M.check()`; `---@param`/`---@return` on local functions follow sibling files (`detectors/*.lua`).

## API choice
- Use `vim.health.start/ok/info/warn/error` (present since Neovim 0.9). The spec Notes mention `report_*`, which is deprecated in 0.10 and may be removed in later versions; the new names work on 0.9+ so no version branch is needed.
- Section headers are drawn by `:checkhealth` itself; the "══" separator in the spec Notes cannot be controlled from the module and is dropped.

## Behaviour — `M.check()`
Sections, in order:

### Environment
- Neovim: checked first in `M.check()`. Below 0.9 → `vim.health.report_start/report_error` (the only names Neovim 0.8 has) with "requires Neovim 0.9+" and stop; otherwise ok with the version string.
- Plugin setup: global user command `Rails` in `vim.api.nvim_get_commands({})` → ok "setup() called", else warn "setup() has not been called (add require(\"rails-tools\").setup() to your config)". Without it the Modules section would show defaults for a plugin that is not running (risk R2).
- Rails project: `detectors.rails.root()` → ok "Rails project detected at <root>", else warn "Not a Rails project (no Gemfile + bin/rails found from <cwd>; detection is cached per session, restart Neovim after creating them)" (risk R1).
- Ruby (only when Rails detected): `vim.fn.executable("ruby") == 1` → `vim.fn.system({ "ruby", "-v" })`, ok with the trimmed first line; non-zero `vim.v.shell_error` or not executable → warn.
- Rails version (only when Rails detected): read `<root>/Gemfile.lock`, first line matching `^    rails (x)`, else `^    railties (x)` → ok "Rails <version>"; missing lockfile or no match → warn "Rails version not found in Gemfile.lock". No `bin/rails -v`: it boots the app and is slow.

### Project (only when Rails detected; otherwise one info line "Skipped: not a Rails project")
- `Gemfile` and `bin/rails` (or `script/rails`) are guaranteed by detection → ok. `Gemfile.lock`: ok when present, warn when missing.
- Test framework: `detectors.test_framework.detect(root)` → ok "RSpec" / "Minitest" / "RSpec and Minitest"; nil → warn "No spec/ or test/ directory".
- Grape: `nvim_get_runtime_file("lua/rails-tools/detectors/grape.lua")`; if the detector exists (then `require` it without pcall, so its errors surface) use its `detect(root)` (ok when detected, info when not); if it does not exist yet (L2-016 not shipped) → info "Grape detection not available yet".

### Optional dependencies
For each `{ module, name, fallback }`:
- `telescope` / telescope.nvim / "pickers fall back to vim.ui.select"
- `toggleterm` / toggleterm.nvim / "terminal falls back to the native terminal"
- `which-key` / which-key.nvim / "keymap groups are not labelled"
`pcall(require, module)` ok → ok "<name> installed", else warn "<name> not installed (<fallback>)".

### Modules
`config.get().modules`, keys sorted alphabetically: `true` → ok "<name>: enabled"; otherwise info "<name>: disabled".

## Tests — `tests/health_spec.lua`
- Stub `vim.health.start/ok/info/warn/error` in `before_each` to record `{ level, msg }` per section; restore in `after_each`.
- Reset `package.loaded` for health, config, detectors before each test; temp dir fixtures like `tests/detectors/rails_spec.lua`; `cd` into the fixture and back.
Cases:
1. Rails project (Gemfile, Gemfile.lock with `    rails (7.1.6)`, bin/rails, spec/) → Environment ok for Rails detected + "Rails 7.1.6"; Project ok for RSpec.
2. Non-Rails dir → warn "Not a Rails project", Project section has the skip info, no Ruby/Rails version lines, no error raised.
3. Rails project without Gemfile.lock → warn about Rails version.
4. Test framework missing → warn; both dirs → "RSpec and Minitest".
5. Optional deps: fake `telescope` via `package.preload` → ok; `toggleterm` absent → warn mentioning the fallback.
6. Modules: `config.setup({ modules = { rspec = true } })` → ok "rspec: enabled", info "gf: disabled".
7. Grape: detector absent → info "not available yet".
8. Ruby not executable: stub `vim.fn.executable` to return 0 for "ruby" → warn.
9. `:checkhealth rails-tools` smoke test: run the real command, assert the health buffer contains "rails-tools" and no "ERROR" from a Lua traceback.
10. `:Rails` not registered → warn "setup() has not been called"; registered → ok.

## Risks (risk-issue, before coding)
- R1 — Stale detection. `detectors/rails.lua:36-55` caches negative results per cwd for the whole session, so health keeps saying "Not a Rails project" after `bin/rails` is created. Health must not change detector caching (out of scope), so the warning tells the user to restart. Status: handled in the plan.
- R2 — Defaults shown without setup. `plugin/rails-tools.lua` does not call `setup()`; `config.get()` returns defaults, so Modules would look "enabled" for a plugin that never started. Status: handled by the setup line in Environment.
- R3 — Blocking call. `vim.fn.system({ "ruby", "-v" })` is synchronous; with a version manager shim it normally returns in well under a second, and only runs when the user opens `:checkhealth`. Accepted.
- R4 — `pcall(require, ...)` for optional deps loads a lazy-loaded plugin as a side effect. Same approach as `ui/terminal.lua`; accepted.
- R5 — Only Neovim 0.9.5 is available in the test environment; `vim.health.*` behaviour on 0.10+ (user runs 0.12) is untested here. Possible; check by running `:checkhealth rails-tools` locally.

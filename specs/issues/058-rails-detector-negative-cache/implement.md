# Implement plan — BF-058 Rails detector caches "not a Rails project" forever

Review: Approved

## Related
- [Original issue](./issue.md)

Source: `specs/issues/058-rails-detector-negative-cache/issue.md` (GitHub #58), `specs/story.md:394-397` (BF-058). Line numbers below checked against `main` (4d02907).

## Decisions made without you
- Fix = stop caching misses. No `DirChanged` autocmd, no TTL.
  - Reason: the first acceptance criterion allows "not cached" as an option, and it needs one deleted line instead of a new autocmd or timer.
- Public clear function = `require("rails-tools.detectors.rails").clear_cache()`, documented in `README.md`. No `:Rails` subcommand.
  - Reason: the acceptance criterion asks only for "a public way ... documented".
- Scope = Rails detector only. `detectors/test_framework.lua` and `detectors/grape.lua` are not changed.
  - Reason: issue #58 title and acceptance criteria target the Rails detector. The remaining stale case is listed under Risks and goes to a follow-up issue.

## Root cause (confirmed from code)
- `lua/rails-tools/detectors/rails.lua:39-41`: any non-nil cache entry for `start_dir` is returned without touching disk.
- `rails.lua:52`: a miss stores `cache[start_dir] = false`, so the miss becomes a permanent cache hit.
- The cache is a module-local table (`rails.lua:7`) with no clear function. Only a Neovim restart (or a `package.loaded` reset, as the tests do) empties it.
- Effect: open Neovim in a folder → run any `:Rails` action before `rails new` creates `Gemfile` + `bin/rails` → every later `rails.root()` for that folder returns nil.
- Every module resolves the root through `rails.root()` (grep `rails.root`): `ui/terminal.lua:20`, `health.lua:209`, `core/generators.lua:13,19`, `core/alternate.lua:17`, `core/console.lua:25,31`, `core/gf.lua:409`, `core/routes.lua:43,49`, `core/schema.lua:160,171,188`, `core/finder.lua:16,22`, `core/controller_view.lua:35`, `core/runner.lua:24,30`, `integrations/grape.lua:60,66`, `integrations/rspec.lua:25`. So the whole plugin acts as "not Rails" for that folder.

## Fix
- Delete `rails.lua:52` (`cache[start_dir] = false`). A miss re-walks the tree on the next call. Positive results stay cached.
- Add `M.clear_cache()` to `rails.lua` that resets `cache = {}`, with LuaDoc. Covers the remaining stale case (project moved or deleted while Neovim is open).
- Document `clear_cache()` in `README.md`.
- No change to `find_root`, `root`, `is_rails`, `executable`, `detectors/init.lua`, `detectors/grape.lua`, `detectors/test_framework.lua`, or any caller.

## Implementation Checklist
1. `lua/rails-tools/detectors/rails.lua`: delete line 52 `cache[start_dir] = false`. Keep line 40 (`return cache[start_dir] or nil`) as is.
2. Same file, after `M.detect` (ends line 54) and before `M.root`, add:
   ```lua
   ---Forget every cached detection result, so the next call re-checks the disk.
   function M.clear_cache()
     cache = {}
   end
   ```
3. `tests/detectors/rails_spec.lua`, inside `describe("detect()")`, add:
   - `it("detects a project created after a negative result")`: `rails.detect(tmp_dir)` is nil → `create_file("Gemfile")` → `create_file("bin/rails")` → `rails.detect(tmp_dir)` is not nil and `.root == tmp_dir`.
4. Same file, new `describe("clear_cache()")` after `describe("detect()")`:
   - `it("re-detects after clearing a positive result")`: `create_file("Gemfile")` → `create_file("bin/rails")` → `rails.detect(tmp_dir)` is not nil → `vim.fn.delete(tmp_dir .. "/Gemfile")` → `rails.clear_cache()` → `rails.detect(tmp_dir)` is nil.
5. Same file, test at line 72 `"negative result is cached (no re-traversal on second call)"`: rename the title only to `"negative result stays nil on a second call"`. Assertions unchanged. List this test change in the final report.
6. `README.md`, after the `### Health Check` section (line 191-193) and before `## License` (line 195), add a `### Detector cache` section with 2 lines:
   - Rails root detection is cached per folder after a match. A folder that is not Rails yet is re-checked on every call.
   - Run `:lua require("rails-tools.detectors.rails").clear_cache()` to force re-detection (e.g. after moving or deleting a project).
7. Run `make test` and `make lint`.
8. Tick BF-058 items in `specs/story.md:395-397` and the acceptance criteria in `issue.md`.

## Risks
- Non-Rails folder with `modules.cmp` on: a completion request that has a receiver calls `schema.resolve()` → `rails.root()` (`integrations/cmp.lua:70`, `core/schema.lua:160`), which now walks up to `/` each time.
  - Cost per level: up to 5 `filereadable`/`isdirectory` calls (`rails.lua:22-23`). Assumption, not measured: negligible for normal folder depth.
- Remaining stale case outside this fix (user-reachable today): run `:Rails alternate` in a folder before `rails new` → `alternate.lua:17` falls back to `uv.cwd()` → `test_framework.lua:39` caches `false` for that folder → after `rails new`, alternate keeps the `"rspec"` default (`alternate.lua:59-60`) even for a Minitest app until restart. Not fixed here (see Decisions). `rails.clear_cache()` does not clear it.
- `detectors/grape.lua` has the same pattern but is only called from `health.lua:146`, after `health.lua:157` skips non-Rails folders. So it is not reached with a stale "not Rails" root.
- Positive results are still never invalidated automatically (moved or deleted project). Accepted. `clear_cache()` is the manual escape.
- New test in step 4 assumes no parent folder of `vim.fn.tempname()` is a Rails root. The existing test at `rails_spec.lua:57-60` already relies on the same assumption.
- Existing tests at `rails_spec.lua:62-70` (positive cache reuse) and `90-101` (shared root entry) keep passing unchanged, since positive caching is untouched.

## Notes
- Do NOT touch: `find_root`, `root`, `is_rails`, `executable`, `detectors/init.lua`, `detectors/grape.lua`, `detectors/test_framework.lua`, callers.
- No new comments besides the LuaDoc on the new public function (project rule: public APIs need LuaDoc).
- Annotation that becomes inaccurate (NOT edited, flag in the final report): `rails.lua:6` `---@type table<string, {is_rails: boolean, root: string}|false>` — `false` is no longer stored.
- Existing test comment at `rails_spec.lua:75` ("should also return nil without traversal") becomes inaccurate (NOT edited, flag in the final report).

## Open questions
1. Also fix the same pattern in `test_framework.lua` / `grape.lua`?
   - Recommended: no. Issue #58 targets the Rails detector. Open a follow-up issue for `test_framework.lua` (the stale case in Risks).
   - Note: `specs/story.md:396` says "detector caches" (plural), while issue #58 says "the detector cache". The plan follows the issue.
2. Expose `clear_cache` as a `:Rails` subcommand too?
   - Recommended: no. A documented Lua function satisfies the acceptance criterion.
3. Existing test "negative result is cached" now describes behaviour the fix removes. Rename, delete, or leave it?
   - Recommended: rename the title only (step 5). Assertions still hold, nothing is weakened, and the name no longer contradicts the fix.

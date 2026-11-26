# Implement plan — BF-064 `cmp.dedupe_with_lsp` matching and Neovim 0.9 support

## Related
- [Original issue](./issue.md)

Source: `specs/issues/064-cmp-dedupe-lsp-never-matches/issue.md` (GitHub #64), `specs/story.md` (BF-064, lines 422-424).

## Root cause (confirmed)
- `lua/rails-tools/integrations/cmp.lua:17` passes the whole list as the filter: `vim.lsp.get_clients({ bufnr = bufnr, name = names })`.
  - Neovim compares `client.name == filter.name`. A table never equals a string → always 0 clients → `rails_schema` items are never hidden.
  - Reproduced on local Neovim 0.13-dev with a dummy in-process client named `ruby_lsp`: `get_clients({ bufnr, name = { "ruby_lsp" } })` returns 0 while the client is attached.
- Neovim 0.9.5 runtime (`runtime/lua/vim/lsp.lua` at tag v0.9.5) has only `lsp.get_active_clients` (line 1850), no `get_clients` → `cmp.lua:17` raises "attempt to call a nil value" as soon as `dedupe_with_lsp` is non-empty and a `.` completion runs.
- Reached by: user sets `cmp = { dedupe_with_lsp = { "ruby_lsp" } }` (README line 94 shows this), opens a Ruby file, types `user.`.
- Tests miss both: `tests/integrations/cmp_spec.lua:50,62,76,88` replace `vim.lsp.get_clients` with fakes; the fake at line 62 even accepts a table `name`.
- CI already runs the test suite on `v0.9.5` and `stable` (`.github/workflows/*.yml`, matrix `neovim: [v0.9.5, stable]`), so the 0.9 acceptance item is covered once the tests use a real client.

## Fix
- `lsp_already_covers_columns` only: pick `vim.lsp.get_clients or vim.lsp.get_active_clients`, list clients attached to the buffer (no `name` filter), return true when any `client.name` is in `names`.
- `get_clients` is tried first, so 0.10+ never calls the deprecated `get_active_clients`.
- Nothing else in `cmp.lua` changes.

## Implementation Checklist
1. `lua/rails-tools/integrations/cmp.lua`, replace the `return` line of `lsp_already_covers_columns` (line 17, after the `#names == 0` guard at lines 14-16) with
   ```lua
   local get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients
   for _, client in ipairs(get_clients({ bufnr = bufnr })) do
     if vim.tbl_contains(names, client.name) then
       return true
     end
   end

   return false
   ```
   Keep the existing LuaDoc and the guard.
2. `tests/integrations/cmp_spec.lua`, remove every replacement of `vim.lsp.get_clients`: the `original_get_clients` local and its save/restore (lines 5, 28, 32) and the fakes in each `it` (lines 50-52, 62-67, 76-78, 88-90).
3. Same file, add local helpers inside the `describe`:
   - `fake_server_cmd()` returns `function(dispatchers)` that returns an in-process RPC table:
     - `request(method, _, callback)`: `initialize` → `callback(nil, { capabilities = {} })`; `shutdown` → `callback(nil, nil)`; return `true, 1`.
     - `notify(method)`: on `exit` mark closing and call `dispatchers.on_exit(0, 15)`; return `true`.
     - `is_closing()` returns the closing flag; `terminate()` marks closing and calls `dispatchers.on_exit(0, 15)`.
   - `attach_dummy_client(name)`: `vim.lsp.start({ name = name, cmd = fake_server_cmd(), root_dir = vim.fn.getcwd() }, { bufnr = bufnr })`, then `vim.wait(1000, ...)` until the client is attached to `bufnr` (use `vim.lsp.get_clients or vim.lsp.get_active_clients`), store the client id.
   - Assert the `vim.wait` return value is `true` with a message such as `"dummy LSP client <name> did not attach"`, so an attach failure is reported as such instead of a wrong item count.
4. Same file, `before_each`: create a scratch buffer (`nvim_create_buf(false, true)`), set it current, keep it in `bufnr`. `after_each`: for each stored client id `vim.lsp.stop_client(id, true)`, `vim.wait` until no client is attached and assert its return value is `true` (message such as `"dummy LSP client did not detach"`), so a leftover client cannot leak into the next test; then delete the buffer. `complete()` passes `bufnr` instead of the hard-coded `1`.
5. Same file, tests (existing titles kept, bodies use the real client):
   - "suggests known columns when no dedupe_with_lsp is configured": no client attached → 1 item.
   - "suppresses columns when a configured LSP client is attached to the buffer": `dedupe_with_lsp = { "ruby_lsp" }`, attach `ruby_lsp` → 0 items.
   - "still suggests columns when the configured LSP client isn't attached": `{ "ruby_lsp" }`, no client → 1 item.
   - "suggests columns after a safe navigation receiver": unchanged except fake removed.
   - New "suppresses columns when any of several configured clients is attached": `{ "solargraph", "ruby_lsp" }`, attach `ruby_lsp` → 0 items.
   - New "still suggests columns when only an unlisted LSP client is attached": `{ "ruby_lsp" }`, attach `solargraph` → 1 item.
6. Run `make test-file FILE=tests/integrations/cmp_spec.lua`, `make test`, `make lint`. CI covers v0.9.5.
7. Tick BF-064 items in `specs/story.md` (lines 422-424) and the acceptance criteria in this folder's `issue.md`.

## Test changes (required by the issue, not weakening)
- All four existing tests lose their `vim.lsp.get_clients` fake (issue criterion 3); assertions stay the same.
- `complete()` uses a real scratch buffer instead of `bufnr = 1`.

## Decisions
1. Filter by name in Lua instead of one `get_clients` call per name: one call, same behaviour on 0.9 and 0.10+.
2. Fake server lives as a local helper in `cmp_spec.lua`; no other spec needs it (grep `vim.lsp` in `tests/` hits only `cmp_spec.lua`).
3. PR uses `Closes #64`: all three GitHub criteria are covered.

## Notes
- Dummy client approach checked on local Neovim 0.13-dev in a scratch script: attach, match `{ "ruby_lsp" }`, no match for `{ "solargraph" }`, match for `{ "solargraph", "ruby_lsp" }`, and detach after `stop_client(id, true)` all behave as expected.
- `terminate` must call `dispatchers.on_exit`; without it the forced stop leaves the client attached (seen in the scratch run).
- Neovim 0.9.5 support for this approach is checked from source only (v0.9.5 `lsp.lua`: `cmd` as function at lines 297/1204, `lsp.start` attaches at line 889, `stop_client` at 1823). Not run locally; CI v0.9.5 job is the check.
- `vim.lsp.stop_client` prints a deprecation notice on 0.13-dev and on current stable v0.12.6 (seen in the review run); the tests still pass. Accepted as test output noise, not a failure.
- Do NOT touch: the rest of `cmp.lua`, `config.lua` defaults, README, `integrations/lsp.lua`. No new comments.

## Decisions made without you
1. `vim.wait` results in the test helper are asserted (checklist steps 3 and 4): attach/detach failures show a clear message, and a leftover client cannot leak into the next test.
2. A string `dedupe_with_lsp` value (e.g. `"ruby_lsp"` instead of `{ "ruby_lsp" }`) gets no guard: accepted limitation. The issue only covers list matching and 0.9 support; the documented type is a list (`config.lua:130` default `{}`, README line 94). After the fix a string value raises during completion (`vim.tbl_contains` expects a table). Can only be reached by a user who ignores the docs.
3. Neovim 0.9.5 is not run locally; the CI v0.9.5 job is the check (source reading of v0.9.5 `lsp.lua` shows no blocker).
4. The `vim.lsp.stop_client` deprecation notice appears on 0.13-dev and on current stable v0.12.6 (reviewer correction of the earlier "no notice on stable" assumption). Accepted as test noise, not a failure; no workaround added.

## Risks to test
- 0.9.5 path is checked from source only (in-process `cmd` function, sync `initialize` callback, unnamed buffer URI `file://`). The real test is the CI v0.9.5 job; if it fails, look at attach first (the `vim.wait` assertion message points to it).
- Detach failure on 0.9.5 (e.g. `terminate` not reaching `on_exit`) would leave a client attached; with the same name and root_dir `reuse_client` re-attaches it in the next test. Covered by the detach assertion; confirm on CI v0.9.5.
- CI stable job output will contain the `stop_client` deprecation notice; check that the job still passes and the notice is not treated as an error.

Review: Approved

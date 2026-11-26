# Test cases: 055 setup() retry after a failed sub-module

Run: `make test-file FILE=tests/init_spec.lua` (pass on branch commit 358f457: tests/init_spec.lua, per risk report scratch run 7/7).

## Risks to test

- [ ] Retry with changed config leaves stale setup from the failed run
  - Test: setup with gf enabled and a forced later failure, retry with `modules.gf = false`, then check `nvim_get_autocmds({ group = "rails_tools_gf" })` (stub the failing module via `package.loaded`).
  - Same idea for `keymaps.enabled = false` (old maps stay) and a changed `keymaps.prefix`.
- [ ] Retry without opts resets config to defaults
  - Test: `setup({ keymaps = { prefix = "<leader>x" } })` with a forced failure, then `setup()`, then check `config.get().keymaps.prefix`.
- [ ] Merge order with BF-054 (both edit `M.setup` and tests/init_spec.lua)
  - Test: after rebasing on whichever merges first, rerun `make test-file FILE=tests/init_spec.lua`; `setup_done = true` must stay after the last gated block and the gf stub cleanup in `after_each` must stay.
- [ ] Retry leaves no duplicate autocmds
  - Test: after the retry, `#nvim_get_autocmds({ group = "rails_tools_schema_cache" }) == 1` and the same for `rails_tools_lsp_schema` (already asserted in the retry test; confirm it still holds).
- [ ] New tests leave global `<leader>r*` maps behind (review SHOULD)
  - Test: check whether any test asserts a leader map is absent; if so, delete the maps in `after_each`.
- [ ] Plugin manager retry path (assumption)
  - Test: manual, check whether `:Lazy reload` calls `setup` again with the same opts.

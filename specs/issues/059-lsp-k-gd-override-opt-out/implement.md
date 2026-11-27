# Implement plan — BF-059 Opt-out and custom keys for the LSP `K`/`gd` override

## Related
- [Original issue](./issue.md)

## Decisions made without you
- New config block `lsp = { hover = "K", definition = "gd" }`. Only a non-empty string maps that key; `false` and `""` mean "no mapping" silently; any other value (e.g. `true`, number, table) warns via `vim.notify_once` and maps nothing.
  - Reason: `vim.tbl_deep_extend("force", ...)` cannot set a key to `nil`, so `false` is the only way to opt out; per-key control covers both "disable" and "choose the keys".
- Default stays `K` / `gd`, still applied with `vim.schedule` after `on_attach` (same as today), so zero-config users see no change.
- If the whole `lsp` value is not a table, both mappings are disabled (`lsp = false` silently; any other non-table value warns via `vim.notify_once`): guard `type(keys) == "table"` before reading `keys.hover` / `keys.definition`.
  - Reason: `vim.tbl_deep_extend` keeps `lsp = false`, and indexing it would raise on every Ruby `LspAttach`.
- Existing buffer mapping (Q1, decided): not detected; override and document. The plugin overrides the configured keys; users who want their own mapping set the key to `false` (or another key) and map the public functions.
  - Reason: Neovim's own default `K` is buffer-local (see Description), so "keep any existing mapping" would disable Rails hover for most users, and telling it apart from a user mapping needs fragile desc matching. The issue allows "or the chosen behaviour is documented".
- Non-string non-false values (Q2, decided by the user): no fallback to the default key; they warn via `vim.notify_once` and map nothing (see first bullet).
- Rails-aware actions become public: `M.hover()` and `M.definition()` in `integrations/lsp.lua` (the current bodies of the `K` / `gd` callbacks, unchanged).
- The existing comment at `lsp.lua:105-109` is kept as is; it stays accurate.
- `modules.schema = false` already skips the whole LSP integration (`init.lua:20-28`); no change there.

## Description
Checked against `main` (82bb64e; `lsp.lua` unchanged on df73693):
- Confirmed: `attach_hover` (`integrations/lsp.lua:62-74`) and `attach_goto_definition` (`lsp.lua:77-91`) hard-code `"K"` and `"gd"` with `buffer = bufnr` (issue cites 66-108; code moved, behaviour same).
- Confirmed: `M.setup` (`lsp.lua:97-116`) calls both inside `vim.schedule` on every `LspAttach` for `ruby`/`eruby`, with no condition, so it always runs after the client's `on_attach` and replaces any `K`/`gd` set there.
- Confirmed: `config.lua` `M.defaults` (lines 42-127) has no `lsp` key; nothing reads a key name for these mappings.
- Confirmed: the Rails-aware logic lives only in anonymous callbacks; the public API is `hover_lines` / `definition_location` (data only), so a user cannot map the full behaviour (float + LSP fallback) themselves.
- Confirmed (Neovim runtime, `$VIMRUNTIME/lua/vim/lsp.lua:866-875`, v0.13-dev): Neovim itself sets a buffer-local `K` (`desc = 'vim.lsp.buf.hover()'`) on attach when `K` is unmapped. So "a buffer-local `K` exists" does not mean the user mapped it (relevant to Q1).

## Design
- `config.lua` `M.defaults`: add `lsp = { hover = "K", definition = "gd" }` after `cmp`.
- `integrations/lsp.lua`:
  - `require("rails-tools.config")` at the top.
  - New public `M.hover()`: body of today's `K` callback (`lsp.lua:64-72`). LuaDoc one-liner.
  - New public `M.definition()`: body of today's `gd` callback (`lsp.lua:79-89`). LuaDoc one-liner.
  - `attach_hover(bufnr, lhs)` / `attach_goto_definition(bufnr, lhs)`: `vim.keymap.set("n", lhs, M.hover, {...same desc...})` / `M.definition`.
  - `M.setup`: inside the scheduled function, read `config.get().lsp`; return if it is not a table; call `attach_hover(args.buf, keys.hover)` only when `keys.hover` is a non-empty string, same for `definition`; warn once via `vim.notify_once` for a non-table `lsp` (other than `false`) or a key value that is neither a string nor `false`. Autocmd, filetype check and `vim.schedule` unchanged.
  - Reword the `M.setup` LuaDoc (`lsp.lua:93-96`) to say the keys come from `config.lsp` (`hover`, `definition`) and `false` disables one. The user approved this rewrite after review.
- `README.md` Configuration block: add `lsp = { hover = "K", definition = "gd" }` with short notes:
  - `false` or `""` disables that key silently; `lsp = false` disables both; a wrong-typed value warns once and maps nothing.
  - The plugin replaces any `K`/`gd` (or configured keys) set in the user's own `on_attach`.
  - With `hover = false` and no `K` of the user's own: on Neovim 0.10+ the built-in `K` (plain LSP hover) remains (`$VIMRUNTIME/doc/news-0.10.txt:199`); on 0.9 `K` falls back to `'keywordprg'`.
  - A 2-line example mapping `require("rails-tools.integrations.lsp").hover` in the user's own `on_attach`.

## Acceptance Criteria
- [ ] Default config: after `LspAttach` on a ruby buffer, `K` and `gd` are buffer-local with descs `Hover Documentation (Rails-aware)` / `Go to Definition (Rails-aware)`.
- [ ] `lsp = { hover = false, definition = false }`: no Rails-aware `K`/`gd`; a user buffer mapping on `K` set before the attach is still there afterwards.
- [ ] `lsp = { hover = "gh", definition = "gD" }`: those keys are mapped with the Rails descs; `K`/`gd` are not.
- [ ] `lsp = false`: attach raises no error and no Rails-aware `K`/`gd` is mapped. `hover = ""` behaves as no mapping. A wrong-typed value (`hover = true`, `lsp = true`) shows one `vim.notify_once` warning and maps nothing.
- [ ] `require("rails-tools.integrations.lsp").hover` and `.definition` are callable and fall back to `vim.lsp.buf.hover()` / `vim.lsp.buf.definition()` outside a recognized column.
- [ ] README documents the option and the override behaviour.
- [ ] All existing `lsp_spec.lua` tests pass unchanged; `make test` and `make lint` pass.

## Implementation Checklist
1. `lua/rails-tools/config.lua`: add `lsp = { hover = "K", definition = "gd" }` to `M.defaults` after `cmp`.
2. `tests/config_spec.lua`: add `"lsp"` to `expected_keys` in "defaults contain every top-level key".
3. `lua/rails-tools/integrations/lsp.lua`:
   - Add `local config = require("rails-tools.config")` with the other requires.
   - Add `M.hover()` and `M.definition()` (moved callback bodies, LuaDoc) above `attach_hover`.
   - Change `attach_hover` / `attach_goto_definition` to take `lhs` (add `---@param lhs string` under the existing `---@param bufnr integer`) and pass `M.hover` / `M.definition` as the rhs; keep `buffer` and `desc`.
   - In `M.setup`'s scheduled function, read `config.get().lsp`; skip both if it is not a table; attach each mapping only when its value is a non-empty string; warn once via `vim.notify_once` for any other value except `false`.
4. `tests/integrations/lsp_spec.lua`: new top-level `describe("integrations.lsp setup()")`:
   - Helper `attach_ruby_buffer()`: new scratch buffer made current with `nvim_set_current_buf(buf)`, `vim.bo[buf].filetype = "ruby"`, `nvim_exec_autocmds("LspAttach", { group = "rails_tools_lsp_schema", buffer = buf, data = { client_id = 0 } })` (the `group` limits the fake event to the plugin's own handler, see Notes), then flush the schedule deterministically: `vim.schedule` a sentinel flag and `vim.wait(1000, function() return flag end)`.
   - `before_each`: `config.setup()`, then `require("rails-tools.integrations.lsp").setup()` (augroup uses `clear = true`, so repeated calls are safe); `after_each`: delete the buffer, `config.setup()`.
   - Default: `maparg("K", "n", false, true).desc == "Hover Documentation (Rails-aware)"`, same for `gd`, and `.buffer == 1`.
   - Disabled: `config.setup({ lsp = { hover = false, definition = false } })`, set `vim.keymap.set("n", "K", fn, { buffer = buf, desc = "user hover" })` before the attach → after attach `K` desc is still `"user hover"`, `gd` desc is not the Rails one.
   - Custom keys: `{ hover = "gh", definition = "gD" }` → `gh`/`gD` have the Rails descs; `K`/`gd` do not.
   - Empty string: `{ hover = "", definition = "gd" }` → `K` desc is not the Rails one; `gd` has the Rails desc.
   - Per-key merge: `{ hover = false }` (definition left at default) → `K` desc is not the Rails one; `gd` has the Rails desc.
   - Whole block off: `config.setup({ lsp = false })` → attach helper raises no error; `K`/`gd` descs are not the Rails ones.
   - Wrong type: `{ hover = true }` → one warning naming `lsp.hover`, `K` not mapped, `gd` mapped; `lsp = true` → one warning, nothing mapped; `false` / `""` → no warning. `vim.notify_once` is stubbed and restored in `after_each`.
   - Public functions: stub `vim.lsp.buf.hover` / `vim.lsp.buf.definition` (restore after), buffer line `foo`, cursor on it, call `lsp.hover()` / `lsp.definition()` → each stub called once.
5. `README.md`: add the `lsp` block to the Configuration example and the notes from Design: `false` disables a key, `lsp = false` disables both, the plugin replaces any `K`/`gd` set in the user's `on_attach`, built-in `K` with `hover = false` (Neovim 0.10+), mapping example.
6. Check the diff against `~/.claude/code-rules/` (core, general, `lua/lua.md`: LuaDoc on public functions, no new comments, 2-space indent as in these files).
7. `make test` → all pass. `make lint` → no warnings.

## Open questions
- Q3. Stale schema data when `modules.schema = false` and the user maps the public functions (see Notes)?
  - Recommended: accept as a known limitation, no code change. It only happens when the user disables schema on purpose, and the cache expires in 300s. Doing it (call `schema.setup()` lazily from `M.hover`) touches startup logic outside this issue.

## Notes
- Checked headless: `require("rails-tools.detectors.rails").root()` returns nil in the plugin repo, so `schema.resolve()` returns nil and `M.hover()` / `M.definition()` take the LSP fallback in step 4.
- Confirmed (headless probe, Neovim v0.13-dev): firing `LspAttach` with a fake `client_id = 0` and no `group` runs Neovim's own global `LspAttach` handler in `$VIMRUNTIME/lua/vim/lsp/on_type_formatting.lua:170-178`, whose `assert(lsp.get_client_by_id(...))` fails and prints a stack trace once that module is loaded. With `group = "rails_tools_lsp_schema"` only the plugin's handler runs and no error is printed. CI runs `v0.9.5` and `stable` (`.github/workflows/ci.yml:15`), so the `group` option is required for a deterministic test.
- `nvim_exec_autocmds` support for the `group` and `data` options on Neovim v0.9.5 is an assumption (not checked locally); the CI `v0.9.5` job is left to confirm it.
- Decision (user, after review): the `M.setup` LuaDoc (`lsp.lua:93-96`) is reworded because it still named fixed `K`/`gd` keys.
- Pre-existing, unrelated to this change: if the buffer is wiped between `LspAttach` and the scheduled callback, `vim.keymap.set` with `buffer = <invalid>` raises (`lsp.lua:110-113`). Not reproduced; not in scope.
- Known limitation (from risk check): with `modules.schema = false`, `schema.setup()` is skipped (`init.lua:20-23`), so a user who maps `M.hover` / `M.definition` themselves gets schema data cached up to 300s (`core/schema.lua:7`) without the save-time invalidation (`core/schema.lua:180-190`). Not fixed here; open question Q3.
- `story.md` BF-059 checkboxes are ticked at finalize, not in this checklist.

Review: Approved

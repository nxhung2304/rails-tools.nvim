# Implement plan — L3-006 Resource Finder

Source specs: `specs/issues/008-resource-finder.md`, `specs/story.md` (L3-006, Commands Reference `:Rails find {resource}`).

## Goal
Pick and open a Rails file by resource type (models, controllers, ...) from the paths in `config.finder.resources`, with Telescope when available and `vim.ui.select` otherwise.

## Scope
- Create `lua/rails-tools/core/finder.lua` with `M.find(resource_type)`.
- `lua/rails-tools/commands.lua`: register `find` → `:Rails find {resource}`.
- Tests: `tests/core/finder_spec.lua`, new cases in `tests/commands_spec.lua`.
- Tick L3-006 in `specs/story.md` and `specs/issues/008-resource-finder.md`.

## Do NOT touch
- `config.lua` (`finder.provider`, `finder.resources`, `finder.cache_ttl = 30` already exist), `cache.lua`, `core/alternate.lua`.
- No keymap (L3-009), no menu entry (L3-008), no Telescope extension (L3-007).
- No new comments; LuaDoc on public functions, `---@param`/`---@return` on locals like sibling files.

## Behaviour — `core/finder.lua`
- D1 Project root: the Rails project of the current file (normal buffer with a name), else the cwd project — same rule as `core/runner.lua` `project_root()`. No root → `vim.notify("Rails: not a Rails project", WARN)`, return.
- D2 Resource type: a key of `config.get().finder.resources` (read at call time), or `"all"`. Nil/empty → warn `"Rails: missing resource type"`. Unknown → warn `"Rails: unknown resource type '<x>'"`. Both return.
- D3 `"all"`: the union of every type's `paths`, each file listed once (`spec/factories` is inside `spec`).
- D4 Scanning: for each path `<root>/<path>` that is a directory, `vim.fs.dir(dir, { depth = math.huge })`; keep entries of type `"file"`; skip any entry whose path has a part starting with `.` (`.keep`, `.gitkeep`, hidden dirs). Results are root-relative paths, de-duplicated, sorted. A missing path is skipped silently.
- D5 Cache: one `cache.new()` instance in the module, key `<root>|<resource_type>`; TTL set from `config.get().finder.cache_ttl` at each call (default 30s). The cached value is the file list only.
- D6 No files → `vim.notify("Rails: no <type> found", INFO)`, no picker.
- D7 Provider from `config.get().finder.provider`:
  - `"native"` → `vim.ui.select`.
  - `"auto"` → Telescope if `pcall(require, "telescope")` succeeds, else `vim.ui.select`.
  - `"telescope"` without telescope → warn `"Rails: telescope.nvim not found, falling back to vim.ui.select"`, use `vim.ui.select` (same as terminal's toggleterm fallback).
- D8 Telescope picker: `pickers.new({}, { prompt_title = "Rails <type>", finder = finders.new_table({ results = files }), sorter = conf.generic_sorter({}), previewer = conf.file_previewer({}), attach_mappings })`; `select_default` replaced: close the prompt, then open the selected file. Same shape as `core/alternate.lua`.
- D9 `vim.ui.select(files, { prompt = "Rails <type>: " }, cb)`; nil choice → nothing.
- D10 Open: `vim.cmd.edit(vim.fn.fnameescape(root .. "/" .. relative))` in the current window.

## Commands
- `:Rails find {resource}` → `finder.find(opts.args)`. `:Rails find` (no arg) → the "missing resource type" warning.

## Tests
`tests/core/finder_spec.lua` — Rails fixture in a temp dir; fake `vim.ui.select`; fake telescope modules via `package.loaded`.
1. Each default type (models, controllers, views, services, policies, jobs, mailers, serializers, specs, factories) lists its files, root-relative, sorted.
2. `"all"` lists files of every type once (factory under `spec/factories` appears once).
3. Custom `paths` (services in `app/services` + `app/interactors`) lists both.
4. Nested dirs are included; hidden files/dirs (`.keep`) are skipped; missing dir is skipped.
5. Selecting an item opens `<root>/<file>` in the current buffer; cancelling opens nothing.
6. Unknown / missing type → warning, no picker. Outside Rails → warning. No files → info, no picker.
7. Cache: a file added within TTL is not listed; listed after TTL expiry (`cache_ttl = 0`).
8. Provider: `native` uses `vim.ui.select` even with telescope present; `auto` with fake telescope uses Telescope and its select action opens the file; `telescope` without telescope warns and falls back.
9. Root from the current file's project when cwd is another project.
`tests/commands_spec.lua`: `:Rails find models` → `find("models")`; `:Rails find` → `find("")`.

## Risks (risk-issue, before coding)
- R1 — Telescope previewer resolves relative paths against cwd, not the file's project root (D1 + D8). Decided: Telescope entries carry an absolute `path` (`<root>/<file>`) with the relative path as display/ordinal.
- R2 — `specs` default paths (`spec`, `test`) also list factories, support files and fixtures. Accepted: it follows the configured paths; users narrow them in config.
- R3 — Cache key ignores `paths`, so a config change inside the TTL shows the old list. Decided: key includes the joined paths.
- R4 — `:edit` with a modified buffer and `nohidden` raises E37 inside the picker callback. Decided: wrap in `pcall` and show the error with `vim.notify(..., ERROR)`.
- R5 — Synchronous scan can pause the UI on large `spec/fixtures` or `all`. Accepted for MVP; cached 30s.
- R6 — Symlinked files are skipped (only type `"file"` kept). Accepted; noted.
- R7 — Telescope is not installed in the test environment; Telescope path is tested only with fake modules.

## Decided after review
- Resources set to `false` or without `paths` are ignored by `"all"` and warn as unknown when asked for directly.
- `"all"` scans only the outermost paths (`spec` covers `spec/factories`); hidden directories are not walked (`vim.fs.dir` `skip`).
- Root is checked before the resource type, so outside Rails the warning is always "not a Rails project".
- `project_root()` stays duplicated with `core/runner.lua`; merging it touches runner and is left for a separate PR.

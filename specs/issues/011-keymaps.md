## **Status:**
- Review: Approved
- PR: Todo

## Metadata
- **Title:** Keymap Registration
- **Phase:** Phase 1 — MVP v0.2
- **GitHub Issue:** #9

---

## Description
Implement default keymap registration with configurable prefix.

Steps:
- Create keymaps module
- Define default keymap bindings
- Support configurable prefix (default: <leader>r)
- Only register if keymaps.enabled = true
- Register keymaps for commands

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/keymaps.lua`

---

## Acceptance Criteria
- [x] Keymaps are registered when config.keymaps.enabled = true
- [x] `<leader>rr` opens Rails menu
- [x] `<leader>ra` opens alternate file
- [x] `<leader>rf` opens resource finder
- [x] `<leader>rc` opens console
- [x] `<leader>rx` opens runner prompt
- [x] Prefix is configurable via config
- [x] Keymaps can be disabled entirely

---

## Implementation Checklist
- [x] Create `lua/rails-tools/keymaps.lua`
- [x] Implement M.setup() function
- [x] Define default keymap bindings table
- [x] Register keymaps using vim.keymap.set
- [x] Check config.keymaps.enabled before registering
- [x] Support custom prefix from config
- [x] Create tests for keymap registration
- [x] Test default prefix
- [x] Test custom prefix
- [x] Test disabled keymaps

---

## Notes
- Default prefix: <leader>r
- Uses mode "n" (normal mode)
- Keymaps are silent and noremap
- Phase 2 keymaps (spec, generator) added when modules enabled
- `<leader>ro` (routes navigator) moved to L3-010: `core/routes.lua` does not exist yet, so the keymap is added together with the routes feature
- A visual-mode runner keymap must not use `<Cmd>Rails runner<CR>`: `<Cmd>` passes no range, so the runner opens its prompt instead of running the selection. Use `:Rails runner<CR>` (Neovim inserts `'<,'>`) or call `require("rails-tools.core.runner").run_visual()` after leaving visual mode.

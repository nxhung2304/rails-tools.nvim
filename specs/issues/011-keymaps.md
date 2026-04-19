## **Status:**
- Review: Todo
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
- [ ] Keymaps are registered when config.keymaps.enabled = true
- [ ] `<leader>rr` opens Rails menu
- [ ] `<leader>ra` opens alternate file
- [ ] `<leader>rf` opens resource finder
- [ ] `<leader>ro` shows routes navigator
- [ ] `<leader>rc` opens console
- [ ] `<leader>rx` opens runner prompt
- [ ] Prefix is configurable via config
- [ ] Keymaps can be disabled entirely

---

## Implementation Checklist
- [ ] Create `lua/rails-tools/keymaps.lua`
- [ ] Implement M.setup() function
- [ ] Define default keymap bindings table
- [ ] Register keymaps using vim.keymap.set
- [ ] Check config.keymaps.enabled before registering
- [ ] Support custom prefix from config
- [ ] Create tests for keymap registration
- [ ] Test default prefix
- [ ] Test custom prefix
- [ ] Test disabled keymaps

---

## Notes
- Default prefix: <leader>r
- Uses mode "n" (normal mode)
- Keymaps are silent and noremap
- Phase 2 keymaps (spec, generator) added when modules enabled

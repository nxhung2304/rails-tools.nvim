## **Status:**
- Review: Approved
- PR: Todo

## Metadata
- **Title:** Telescope Integration
- **Phase:** Phase 1 — MVP v0.2
- **GitHub Issue:** #7

---

## Description
Implement Telescope pickers for rails-tools commands.

Steps:
- Create Telescope extension module
- Register extension with Telescope
- Implement pickers for: models, controllers, views, services, specs, routes
- Export pickers for external use

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/telescope/init.lua`
- Telescope loader: `lua/telescope/_extensions/rails.lua` (Telescope only finds extensions by this path)
- Commands: `:Telescope rails models`, `:Telescope rails controllers`, etc.

---

## Acceptance Criteria
- [x] Telescope extension is registered if telescope.nvim available
- [x] `:Telescope rails models` opens models picker
- [x] `:Telescope rails controllers` opens controllers picker
- [x] `:Telescope rails views` opens views picker
- [x] `:Telescope rails services` opens services picker
- [x] `:Telescope rails specs` opens specs picker
- [ ] `:Telescope rails routes` opens routes picker — moved to L3-010 (routes module does not exist yet)
- [x] `:Telescope rails grape` opens Grape routes picker (placeholder message until L4-017)
- [x] Gracefully handles missing telescope.nvim

---

## Implementation Checklist
- [x] Create `lua/rails-tools/telescope/init.lua`
- [x] Define exports table for Telescope registration
- [x] Implement models picker
- [x] Implement controllers picker
- [x] Implement views picker
- [x] Implement services picker
- [x] Implement specs picker
- [ ] Implement routes picker — moved to L3-010
- [x] Implement grape picker (placeholder for Phase 2)
- [x] Create `lua/telescope/_extensions/rails.lua` calling `register_extension`
- [x] Register extension in init.lua main file
- [x] Test each picker

---

## Notes
- Approved with two changes: routes picker moves to L3-010; `lua/telescope/_extensions/rails.lua` added because Telescope's `load_extension` only requires `telescope._extensions.<name>` (checked in telescope.nvim `lua/telescope/_extensions/init.lua`).
- Resource pickers reuse `core/finder.lua`: `finder.find(type, { provider = "telescope", picker_opts = opts })`, so `:Telescope rails models theme=dropdown` works.
- Verified: unit tests (`tests/telescope/init_spec.lua`, new cases in `tests/core/finder_spec.lua`) and a headless run with real telescope.nvim on Neovim 0.9.5 in `test-app/`: models 2, controllers 3, services 2, specs 16 results, Enter opens the file; views shows "no views found" (test-app has no views); grape shows the placeholder message.
- Uses require("telescope").register_extension()
- Only registers if telescope.nvim is available
- Falls back to vim.ui.select if Telescope not available

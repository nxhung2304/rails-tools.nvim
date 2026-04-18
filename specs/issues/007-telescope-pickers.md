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
- Commands: `:Telescope rails models`, `:Telescope rails controllers`, etc.

---

## Acceptance Criteria
- [ ] Telescope extension is registered if telescope.nvim available
- [ ] `:Telescope rails models` opens models picker
- [ ] `:Telescope rails controllers` opens controllers picker
- [ ] `:Telescope rails views` opens views picker
- [ ] `:Telescope rails services` opens services picker
- [ ] `:Telescope rails specs` opens specs picker
- [ ] `:Telescope rails routes` opens routes picker
- [ ] `:Telescope rails grape` opens Grape routes picker
- [ ] Gracefully handles missing telescope.nvim

---

## Implementation Checklist
- [ ] Create `lua/rails-tools/telescope/init.lua`
- [ ] Define exports table for Telescope registration
- [ ] Implement models picker
- [ ] Implement controllers picker
- [ ] Implement views picker
- [ ] Implement services picker
- [ ] Implement specs picker
- [ ] Implement routes picker
- [ ] Implement grape picker (placeholder for Phase 2)
- [ ] Register extension in init.lua main file
- [ ] Test each picker

---

## Notes
- Uses require("telescope").register_extension()
- Only registers if telescope.nvim is available
- Falls back to vim.ui.select if Telescope not available

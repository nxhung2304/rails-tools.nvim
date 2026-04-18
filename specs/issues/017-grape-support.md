## **Status:**
- Review: Approved
- PR: Todo

## Metadata
- **Title:** Grape API Support
- **Phase:** Phase 2 — Expansion v0.6
- **GitHub Issue:** #17

---

## Description
Implement Grape API integration for Rails API projects.

Steps:
- Implement Grape routes parser
- Implement Grape endpoint finder
- Display in Telescope or menu

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/integrations/grape.lua`
- Command: `:Rails grape routes`

---

## Acceptance Criteria
- [ ] Parses Grape routes
- [ ] Displays Grape endpoints
- [ ] Integrates with Telescope
- [ ] Shows in Rails menu when enabled

---

## Implementation Checklist
- [ ] Create `lua/rails-tools/integrations/grape.lua`
- [ ] Implement Grape routes parser
- [ ] Implement endpoint finder
- [ ] Integrate with Telescope
- [ ] Create `tests/integrations/grape_spec.lua`
- [ ] Test Grape routes parsing
- [ ] Test endpoint display

---

## Notes
- Only active when modules.grape = true
- Requires Grape API detection
- Uses similar pattern to Rails routes

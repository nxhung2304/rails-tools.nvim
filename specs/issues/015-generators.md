## **Status:**
- Review: Approved
- PR: Todo

## Metadata
- **Title:** Rails Generators
- **Phase:** Phase 2 — Expansion v0.5
- **GitHub Issue:** #15

---

## Description
Implement Rails generators wrapper to run generators from Neovim.

Steps:
- Implement `rails generate` command wrapper
- Support various generator types (model, controller, etc.)
- Display generator output

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/core/generators.lua`
- Command: `:RailsGenerate {args}`
- Keymap: `<leader>rg`

---

## Acceptance Criteria
- [ ] `generators.run(args)` executes `rails generate {args}`
- [ ] Supports model generation
- [ ] Supports controller generation
- [ ] Supports migration generation
- [ ] Displays generator output
- [ ] Shows errors on failure

---

## Implementation Checklist
- [ ] Create `lua/rails-tools/core/generators.lua`
- [ ] Implement M.run(args) function
- [ ] Create `tests/core/generators_spec.lua`
- [ ] Test various generator types
- [ ] Test error handling

---

## Notes
- Only active when modules.generators = true
- Uses terminal abstraction
- Command: `rails generate {args}`

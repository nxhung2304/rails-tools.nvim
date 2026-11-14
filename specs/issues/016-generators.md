## **Status:**
- Review: Todo
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
- Command: `:Rails generate {args}`
- Keymap: `<leader>rg`

---

## Acceptance Criteria
- [x] `generators.run(args)` executes `rails generate {args}`
- [x] Supports model generation
- [x] Supports controller generation
- [x] Supports migration generation
- [x] Displays generator output
- [x] Shows errors on failure

---

## Implementation Checklist
- [x] Create `lua/rails-tools/core/generators.lua`
- [x] Implement M.run(args) function
- [x] Create `tests/core/generators_spec.lua`
- [x] Test various generator types
- [x] Test error handling

---

## Notes
- Only active when modules.generators = true
- Uses terminal abstraction
- Command: `rails generate {args}`

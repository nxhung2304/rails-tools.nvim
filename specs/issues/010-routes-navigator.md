## **Status:**
- Review: Approved
- PR: Todo

## Metadata
- **Title:** Routes Navigator
- **Phase:** Phase 1 — MVP v0.3
- **GitHub Issue:** #10

---

## Description
Implement Rails routes parser and navigator to view and jump to controller#action.

Steps:
- Check cache with TTL from config
- If cache expired: run `bin/rails routes --expanded` async
- Parse output into list: { method, path, controller_action, name }
- Save cache
- Display in picker (Telescope or vim.ui.select)
- Parse controller#action → file and method
- Open file at method

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/core/routes.lua`
- Command: `:RailsRoutes`

---

## Acceptance Criteria
- [ ] `routes.show()` displays routes in picker
- [ ] `routes.refresh()` clears cache and re-parses
- [ ] `routes.goto_action()` jumps to controller#action from selected route
- [ ] Routes are cached with TTL from config
- [ ] `rails routes --expanded` runs async (non-blocking)
- [ ] Parse format: `GET /users users#index`
- [ ] Handles namespaced routes: `admin/users#index`
- [ ] Opens `app/controllers/users_controller.rb` at `def index` method
- [ ] Shows loading indicator while parsing
- [ ] Shows error message if routes command fails

---

## Implementation Checklist
- [ ] Create `lua/rails-tools/core/routes.lua`
- [ ] Create `lua/rails-tools/cache.lua` (shared cache module for all modules)
- [ ] Implement M.show() function
- [ ] Implement M.refresh() function
- [ ] Implement M.goto_action() function
- [ ] Implement async shell command runner
- [ ] Implement routes output parser
- [ ] Implement controller#action → file locator
- [ ] Implement method line finder
- [ ] Integrate with cache module
- [ ] Create `tests/core/routes_spec.lua`
- [ ] Write tests for route parsing
- [ ] Write tests for controller lookup
- [ ] Test async loading

---

## Notes
- Uses vim.fn.jobstart for async command
- Parse output line by line
- Cache TTL from config (default 300s)
- Force refresh with `:RailsRoutes!`

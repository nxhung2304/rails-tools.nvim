## **Status:**
- Review: Todo
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
- Parse the `--expanded` block output (one `--[ Route N ]--` block per route)
  into a list: { name, verb, path, controller_action, source_location }
- Save cache
- Display in picker (Telescope or vim.ui.select)
- Map `controller#action` → file and method. The output already resolves
  `namespace` / `scope module:`, so `admin/users#index` →
  `app/controllers/admin/users_controller.rb` is a direct path mapping
- Open file at method

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/core/routes.lua`
- Command: `:Rails routes`

---

## Acceptance Criteria
- [ ] `routes.show()` displays routes in picker
- [ ] `routes.refresh()` clears cache and re-parses
- [ ] `routes.goto_action()` jumps to controller#action from selected route
- [ ] Routes are cached with TTL from config
- [ ] `rails routes --expanded` runs async (non-blocking)
- [ ] Parses `--expanded` blocks: `Prefix | users`, `Verb | GET`,
      `URI | /users(.:format)`, `Controller#Action | users#index`
- [ ] Reads `Source Location` when present (Rails 7.1+); works without it on older Rails
- [ ] `users#index` opens `app/controllers/users_controller.rb` at `def index`
- [ ] Namespaced `admin/users#index` opens `app/controllers/admin/users_controller.rb` at `def index`
- [ ] Routes without a `controller#action` (mounted engines / Rack apps,
      `redirect(...)`) are listed but not navigable, with a notice instead of an error
- [ ] Shows loading indicator while parsing
- [ ] Shows error message if routes command fails

---

## Implementation Checklist
- [ ] Create `lua/rails-tools/core/routes.lua`
- [x] Create `lua/rails-tools/cache.lua` (shared cache module — already exists, reuse it)
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
- Parse output block by block (`--expanded` format), not line by line
- Error message on failure includes exit code and stderr
- Cache TTL from config (default 300s)
- Force refresh with `:Rails routes!`

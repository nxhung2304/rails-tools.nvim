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
- [x] `routes.show()` displays routes in picker
- [x] `routes.refresh()` clears cache and re-parses
- [x] `routes.goto_action()` jumps to controller#action from selected route
- [x] Routes are cached with TTL from config
- [x] `rails routes --expanded` runs async (non-blocking)
- [x] Parses `--expanded` blocks: `Prefix | users`, `Verb | GET`,
      `URI | /users(.:format)`, `Controller#Action | users#index`
- [x] Reads `Source Location` when present (Rails 7.1+); works without it on older Rails
- [x] `users#index` opens `app/controllers/users_controller.rb` at `def index`
- [x] Namespaced `admin/users#index` opens `app/controllers/admin/users_controller.rb` at `def index`
- [x] Routes without a `controller#action` (mounted engines / Rack apps,
      `redirect(...)`) are listed but not navigable, with a notice instead of an error
- [x] Shows loading indicator while parsing
- [x] Shows error message if routes command fails

---

## Implementation Checklist
- [x] Create `lua/rails-tools/core/routes.lua`
- [x] Create `lua/rails-tools/cache.lua` (shared cache module — already exists, reuse it)
- [x] Implement M.show() function
- [x] Implement M.refresh() function
- [x] Implement M.goto_action() function
- [x] Implement async shell command runner
- [x] Implement routes output parser
- [x] Implement controller#action → file locator
- [x] Implement method line finder
- [x] Integrate with cache module
- [x] Create `tests/core/routes_spec.lua`
- [x] Write tests for route parsing
- [x] Write tests for controller lookup
- [x] Test async loading

---

## Notes
- Uses vim.fn.jobstart for async command
- Parse output block by block (`--expanded` format), not line by line
- Error message on failure includes exit code and stderr
- Cache TTL from config (default 300s)
- Force refresh with `:Rails routes!`

## **Status:**
- Review: Approved
- PR: Draft

## Metadata
- **Title:** Health Check
- **Phase:** Phase 1 — MVP v0.1
- **GitHub Issue:** #5

---

## Description
Implement health check command to verify plugin setup and Rails environment.

Steps:
- Create health module following Neovim's :checkhealth format
- Check Neovim version (>= 0.9)
- Check Rails project detection
- Check Ruby and Rails versions
- Check optional dependencies (telescope, toggleterm, which-key)
- Check project details (Gemfile, bin/rails, test framework)
- Check module status (enabled/disabled)

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/health.lua`
- Command: `:checkhealth rails-tools`

---

## Acceptance Criteria
- [x] Health check runs via `:checkhealth rails-tools`
- [x] Shows Environment section: Neovim version, Rails detection, Ruby version, Rails version
- [x] Shows Project section: Gemfile, bin/rails, test framework, Grape detection
- [x] Shows Modules section: status of each module (OK, DISABLED)
- [x] Checks for telescope.nvim availability
- [x] Checks for toggleterm.nvim availability
- [x] Checks for which-key.nvim availability
- [x] Shows warnings for missing optional dependencies
- [x] Handles non-Rails projects gracefully

---

## Implementation Checklist
- [x] Create `lua/rails-tools/health.lua`
- [x] Implement M.check() function
- [x] Check Neovim version
- [x] Check Rails project detection
- [x] Check Ruby version (if Rails detected)
- [x] Check Rails version (if Rails detected)
- [x] Check optional dependencies
- [x] Check project status
- [x] Check module status
- [x] Format output according to :checkhealth conventions
- [x] Test health check on Rails project
- [x] Test health check on non-Rails project

---

## Notes
- Uses vim.health.report_start(), report_ok(), report_warn(), report_error()
- Must be named `lua/rails-tools/health.lua` for auto-discovery
- Section headers use "══" separator

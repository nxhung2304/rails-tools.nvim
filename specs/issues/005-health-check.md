## **Status:**
- Review: Approved
- PR: Todo

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
- [ ] Health check runs via `:checkhealth rails-tools`
- [ ] Shows Environment section: Neovim version, Rails detection, Ruby version, Rails version
- [ ] Shows Project section: Gemfile, bin/rails, test framework, Grape detection
- [ ] Shows Modules section: status of each module (OK, DISABLED)
- [ ] Checks for telescope.nvim availability
- [ ] Checks for toggleterm.nvim availability
- [ ] Checks for which-key.nvim availability
- [ ] Shows warnings for missing optional dependencies
- [ ] Handles non-Rails projects gracefully

---

## Implementation Checklist
- [ ] Create `lua/rails-tools/health.lua`
- [ ] Implement M.check() function
- [ ] Check Neovim version
- [ ] Check Rails project detection
- [ ] Check Ruby version (if Rails detected)
- [ ] Check Rails version (if Rails detected)
- [ ] Check optional dependencies
- [ ] Check project status
- [ ] Check module status
- [ ] Format output according to :checkhealth conventions
- [ ] Test health check on Rails project
- [ ] Test health check on non-Rails project

---

## Notes
- Uses vim.health.report_start(), report_ok(), report_warn(), report_error()
- Must be named `lua/rails-tools/health.lua` for auto-discovery
- Section headers use "══" separator

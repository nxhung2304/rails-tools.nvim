## **Status:**
- Review: Todo
- PR: Todo

## Metadata
- **Title:** RSpec Runner
- **Phase:** Phase 2 — Expansion v0.4
- **GitHub Issue:** #14

---

## Description
Implement RSpec runner to execute tests from Neovim.

Steps:
- Implement nearest spec detection and execution
- Implement spec file execution
- Implement last spec re-run
- Display results in terminal or quickfix

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/integrations/rspec.lua`
- Commands: `:Rails spec nearest`, `:Rails spec file`, `:Rails spec last`
- Keymaps: `<leader>rs`, `<leader>rS`

---

## Acceptance Criteria
- [x] Runs nearest spec from cursor
- [x] Runs entire spec file
- [x] Re-runs last executed spec
- [x] Displays test results
- [x] Handles test failures
- [x] Works with RSpec test framework

---

## Implementation Checklist
- [x] Create `lua/rails-tools/integrations/rspec.lua`
- [x] Implement M.run_nearest() function
- [x] Implement M.run_file() function
- [x] Implement M.run_last() function
- [x] Create tests for RSpec runner
- [x] Test nearest spec execution
- [x] Test file execution
- [x] Test last spec re-run

---

## Notes
- Only active when modules.rspec = true
- Uses terminal abstraction
- Caches last executed spec for re-run

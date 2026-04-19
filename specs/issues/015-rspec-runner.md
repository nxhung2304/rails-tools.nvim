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
- [ ] Runs nearest spec from cursor
- [ ] Runs entire spec file
- [ ] Re-runs last executed spec
- [ ] Displays test results
- [ ] Handles test failures
- [ ] Works with RSpec test framework

---

## Implementation Checklist
- [ ] Create `lua/rails-tools/integrations/rspec.lua`
- [ ] Implement M.run_nearest() function
- [ ] Implement M.run_file() function
- [ ] Implement M.run_last() function
- [ ] Create tests for RSpec runner
- [ ] Test nearest spec execution
- [ ] Test file execution
- [ ] Test last spec re-run

---

## Notes
- Only active when modules.rspec = true
- Uses terminal abstraction
- Caches last executed spec for re-run

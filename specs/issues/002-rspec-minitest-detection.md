## **Status:**
- Review: Approved
- PR: Todo

## Metadata
- **Title:** RSpec/Minitest Detection
- **Phase:** Phase 1 — MVP v0.1
- **GitHub Issue:** #2

---

## Description
Implement test framework detection to determine if project uses RSpec or Minitest.

Steps:
- Check for spec/ directory → "rspec"
- Check for test/ directory → "minitest"
- If both exist, check Gemfile for gem 'rspec-rails'
- Return detection result

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/detectors/test_framework.lua`

---

## Acceptance Criteria
- [ ] `rspec_detector.detect()` returns "rspec" for RSpec projects
- [ ] `rspec_detector.detect()` returns "minitest" for Minitest projects
- [ ] `rspec_detector.detect()` returns nil if neither detected
- [ ] `rspec_detector.is_rspec()` returns boolean
- [ ] `rspec_detector.is_minitest()` returns boolean
- [ ] Correctly handles projects with both spec/ and test/ directories

---

## Implementation Checklist
- [ ] Create `lua/rails-tools/detectors/test_framework.lua`
- [ ] Implement `detect()` function
- [ ] Implement `is_rspec()` function
- [ ] Implement `is_minitest()` function
- [ ] Create `tests/detectors/test_framework_spec.lua`
- [ ] Write tests for RSpec detection
- [ ] Write tests for Minitest detection
- [ ] Write tests for edge cases

---

## Notes
- Detection is lazy, only called when needed
- Result is cached for performance
- Used by other modules like alternate file mappings

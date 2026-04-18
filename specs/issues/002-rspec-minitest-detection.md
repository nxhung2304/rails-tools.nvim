## **Status:**
- Review: Approved
- PR: Draft

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
- [x] `rspec_detector.detect()` returns "rspec" for RSpec projects
- [x] `rspec_detector.detect()` returns "minitest" for Minitest projects
- [x] `rspec_detector.detect()` returns nil if neither detected
- [x] `rspec_detector.is_rspec()` returns boolean
- [x] `rspec_detector.is_minitest()` returns boolean
- [x] Correctly handles projects with both spec/ and test/ directories

---

## Implementation Checklist
- [x] Create `lua/rails-tools/detectors/test_framework.lua`
- [x] Implement `detect()` function
- [x] Implement `is_rspec()` function
- [x] Implement `is_minitest()` function
- [x] Create `tests/detectors/test_framework_spec.lua`
- [x] Write tests for RSpec detection
- [x] Write tests for Minitest detection
- [x] Write tests for edge cases

---

## Notes
- Detection is lazy, only called when needed
- Result is cached for performance
- Used by other modules like alternate file mappings

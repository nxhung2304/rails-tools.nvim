## **Status:**
- Review: Todo
- PR: Todo

## Metadata
- **Title:** Grape API Detection
- **Phase:** Phase 2 — Expansion v0.6
- **GitHub Issue:** #16

---

## Description
Implement Grape API detection to identify projects using Grape.

Steps:
- Check for app/api/ directory existence
- Check Gemfile for grape gem
- Return detection result

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/detectors/grape.lua`

---

## Acceptance Criteria
- [x] `detector.detect()` returns true if Grape detected
- [x] Checks app/api/ directory
- [x] Checks Gemfile for grape gem
- [x] Returns false if not detected

---

## Implementation Checklist
- [x] Create `lua/rails-tools/detectors/grape.lua`
- [x] Implement M.detect() function
- [x] Create `tests/detectors/grape_spec.lua`
- [x] Test Grape detection
- [x] Test non-Grape project

---

## Notes
- Both conditions must be true for positive detection
- Used by grape integration module

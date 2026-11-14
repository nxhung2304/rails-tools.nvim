## **Status:**
- Review: Approved
- PR: Todo

## Metadata
- **Title:** Test Marker (Focus/Unfocus)
- **Phase:** Phase 2 — Expansion v0.7
- **GitHub Issue:** #18

---

## Description
Implement test marker to focus/unfocus tests by adding/removing `fit`, `fcontext`, etc.

Steps:
- Implement focus detection for RSpec
- Implement focus/unfocus toggle
- Support cursor position detection

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/integrations/test_marker.lua`

---

## Acceptance Criteria
- [x] Detects if test is focused
- [x] Adds focus marker (fit, fcontext)
- [x] Removes focus marker
- [x] Toggles focus status

---

## Implementation Checklist
- [x] Create `lua/rails-tools/integrations/test_marker.lua`
- [x] Implement M.is_focused() function
- [x] Implement M.focus() function
- [x] Implement M.unfocus() function
- [x] Implement M.toggle() function
- [x] Create tests for test marker
- [x] Test focus detection
- [x] Test focus/unfocus toggle

---

## Notes
- Only active when modules.test_marker = true
- Supports RSpec syntax (fit, fdescribe, fcontext)

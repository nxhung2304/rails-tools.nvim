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
- [ ] Detects if test is focused
- [ ] Adds focus marker (fit, fcontext)
- [ ] Removes focus marker
- [ ] Toggles focus status

---

## Implementation Checklist
- [ ] Create `lua/rails-tools/integrations/test_marker.lua`
- [ ] Implement M.is_focused() function
- [ ] Implement M.focus() function
- [ ] Implement M.unfocus() function
- [ ] Implement M.toggle() function
- [ ] Create tests for test marker
- [ ] Test focus detection
- [ ] Test focus/unfocus toggle

---

## Notes
- Only active when modules.test_marker = true
- Supports RSpec syntax (fit, fdescribe, fcontext)

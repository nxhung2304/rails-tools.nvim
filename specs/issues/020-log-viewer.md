## **Status:**
- Review: Approved
- PR: Todo

## Metadata
- **Title:** Log Viewer
- **Phase:** Phase 3 — Polish v0.8
- **GitHub Issue:** #20

---

## Description
Implement Rails log viewer to inspect application logs.

Steps:
- Locate log files (development.log, test.log, production.log)
- Parse and display log entries
- Support filtering and searching

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/core/log_viewer.lua`

---

## Acceptance Criteria
- [ ] Opens log files
- [ ] Parses log entries
- [ ] Supports filtering by level (debug, info, warn, error)
- [ ] Integrates with Telescope

---

## Implementation Checklist
- [ ] Create `lua/rails-tools/core/log_viewer.lua`
- [ ] Implement log parser
- [ ] Implement filter functionality
- [ ] Integrate with Telescope
- [ ] Create tests for log viewer
- [ ] Test log parsing
- [ ] Test filtering

---

## Notes
- Auto-detects log directory
- Supports tailing logs

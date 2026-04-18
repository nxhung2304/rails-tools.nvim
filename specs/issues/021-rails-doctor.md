## **Status:**
- Review: Approved
- PR: Todo

## Metadata
- **Title:** Rails Doctor
- **Phase:** Phase 3 — Polish v0.9
- **GitHub Issue:** #21

---

## Description
Implement Rails doctor to diagnose project issues.

Steps:
- Run various checks (pending migrations, outdated gems, etc.)
- Display diagnostic results
- Suggest fixes

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/core/doctor.lua`
- Command: `:RailsDoctor`

---

## Acceptance Criteria
- [ ] Checks for pending migrations
- [ ] Checks for outdated gems
- [ ] Checks for common issues
- [ ] Displays diagnostic results
- [ ] Provides suggestions

---

## Implementation Checklist
- [ ] Create `lua/rails-tools/core/doctor.lua`
- [ ] Implement migration check
- [ ] Implement gem check
- [ ] Implement other diagnostic checks
- [ ] Create tests for Rails doctor
- [ ] Test various diagnostics

---

## Notes
- Runs async for performance
- Results cached with TTL
- Extensible for additional checks

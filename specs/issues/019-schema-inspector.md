## **Status:**
- Review: Approved
- PR: Todo

## Metadata
- **Title:** Schema Inspector
- **Phase:** Phase 3 — Polish v0.8
- **GitHub Issue:** #19

---

## Description
Implement schema inspector to view database table structures.

Steps:
- Parse db/schema.rb or migration files
- Display table structures
- Show columns, types, and indexes

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/core/schema.lua`

---

## Acceptance Criteria
- [ ] Parses db/schema.rb
- [ ] Displays table structures
- [ ] Shows column names and types
- [ ] Shows indexes
- [ ] Integrates with Telescope

---

## Implementation Checklist
- [ ] Create `lua/rails-tools/core/schema.lua`
- [ ] Integrate with `lua/rails-tools/cache.lua` for schema caching
- [ ] Implement schema parser
- [ ] Implement table display
- [ ] Integrate with Telescope
- [ ] Create tests for schema inspector
- [ ] Test schema parsing
- [ ] Test display functionality

---

## Notes
- Caches schema for performance
- Supports both schema.rb and migrations

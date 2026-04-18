## **Status:**
- Review: Approved
- PR: Todo

## Metadata
- **Title:** Alternate File Navigation
- **Phase:** Phase 1 — MVP v0.1
- **GitHub Issue:** #3

---

## Description
Implement alternate file navigation to switch between implementation files and their corresponding test/spec files.

Steps:
- Get relative path of current file from Rails root
- Iterate through custom_mappings first, then default mappings
- Match pattern → generate target path
- If target exists, open it
- If target doesn't exist, ask user to create
- If no mapping matches, notify user

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/core/alternate.lua`
- Mappings defined in `lua/rails-tools/config.lua`

---

## Acceptance Criteria
- [ ] `alternate.open()` opens the alternate file for current buffer
- [ ] `alternate.get(filepath)` returns alternate path without opening
- [ ] Supports Model ↔ Spec mapping
- [ ] Supports Controller ↔ Request Spec mapping
- [ ] Supports Service ↔ Spec mapping
- [ ] Supports Policy ↔ Spec mapping
- [ ] Supports Job ↔ Spec mapping
- [ ] Supports Mailer ↔ Spec mapping
- [ ] Supports Serializer ↔ Spec mapping
- [ ] Custom mappings have priority over default
- [ ] Handles nested namespaces (e.g., app/models/admin/user.rb)
- [ ] Asks to create file if alternate doesn't exist
- [ ] Shows clear message when no alternate found

---

## Implementation Checklist
- [ ] Create `lua/rails-tools/core/alternate.lua`
- [ ] Implement `open()` function
- [ ] Implement `get(filepath)` function
- [ ] Add default mappings in config.lua
- [ ] Support custom_mappings override
- [ ] Create `tests/core/alternate_spec.lua`
- [ ] Write tests for all default mappings
- [ ] Write tests for custom mappings
- [ ] Write tests for nested namespaces
- [ ] Write tests for edge cases

---

## Notes
- Uses regex capture groups (%1, %2, etc.) for path transformations
- Uses vim.ui.input for file creation prompt
- Gracefully handles files outside Rails root

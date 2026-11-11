## **Status:**
- Review: Approved
- PR: Draft

## Metadata
- **Title:** Rails Console
- **Phase:** Phase 1 — MVP v0.3
- **GitHub Issue:** #11

---

## Description
Implement Rails console integration to open interactive Rails console.

Steps:
- Get command from config (default: "rails console")
- Open terminal via ui/terminal.lua
- Execute command

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/core/console.lua`
- Command: `:Rails console`

---

## Acceptance Criteria
- [x] `console.open()` opens Rails console
- [x] `console.toggle()` toggles console window
- [x] Uses terminal abstraction layer
- [x] Uses config.console.command for command override
- [x] Works with both toggleterm and native terminal
- [x] Maintains console state for toggle

---

## Implementation Checklist
- [x] Create `lua/rails-tools/core/console.lua`
- [x] Implement M.open() function
- [x] Implement M.toggle() function
- [x] Integrate with ui/terminal.lua
- [x] Read config.console.command
- [x] Register `:Rails console` subcommand
- [x] Create tests for console module
- [x] Test console open
- [x] Test console toggle
- [x] Test with custom command

---

## Notes
- Default command: "rails console"
- Can be overridden: "bundle exec rails c"
- Uses terminal abstraction for provider flexibility

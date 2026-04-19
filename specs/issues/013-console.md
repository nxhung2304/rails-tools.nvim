## **Status:**
- Review: Todo
- PR: Todo

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
- [ ] `console.open()` opens Rails console
- [ ] `console.toggle()` toggles console window
- [ ] Uses terminal abstraction layer
- [ ] Uses config.console.command for command override
- [ ] Works with both toggleterm and native terminal
- [ ] Maintains console state for toggle

---

## Implementation Checklist
- [ ] Create `lua/rails-tools/core/console.lua`
- [ ] Implement M.open() function
- [ ] Implement M.toggle() function
- [ ] Integrate with ui/terminal.lua
- [ ] Read config.console.command
- [ ] Register `:Rails console` subcommand
- [ ] Create tests for console module
- [ ] Test console open
- [ ] Test console toggle
- [ ] Test with custom command

---

## Notes
- Default command: "rails console"
- Can be overridden: "bundle exec rails c"
- Uses terminal abstraction for provider flexibility

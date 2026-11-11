## **Status:**
- Review: Approved
- PR: Draft

## Metadata
- **Title:** Rails Runner
- **Phase:** Phase 1 — MVP v0.3
- **GitHub Issue:** #12

---

## Description
Implement Rails runner to execute code snippets quickly.

Steps:
- Accept code string, prompt, or visual selection
- Execute via `rails runner`
- Display output in terminal or notification

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/core/runner.lua`
- Commands: `:Rails runner {code}`, `:Rails runner` (no args = prompt)

---

## Acceptance Criteria
- [x] `runner.run(code)` executes code string
- [x] `runner.run_prompt()` opens input prompt for code
- [x] `runner.run_visual()` executes visual selection
- [x] Uses config.runner.command (default: "rails runner")
- [x] Displays output to user
- [x] Shows error on failure

---

## Implementation Checklist
- [x] Create `lua/rails-tools/core/runner.lua`
- [x] Implement M.run(code) function
- [x] Implement M.run_prompt() function
- [x] Implement M.run_visual() function
- [x] Integrate with ui/terminal.lua
- [x] Read config.runner.command
- [x] Register `:Rails runner {code}` subcommand
- [x] Register `:Rails runner` (no args) subcommand for prompt
- [x] Create tests for runner module
- [x] Test code execution
- [x] Test prompt input
- [x] Test visual selection

---

## Notes
- Default command: "rails runner"
- Can be overridden via config
- Uses terminal for interactive commands
- Uses vim.notify for quick results

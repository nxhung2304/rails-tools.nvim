## **Status:**
- Review: Todo
- PR: Todo

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
- [ ] `runner.run(code)` executes code string
- [ ] `runner.run_prompt()` opens input prompt for code
- [ ] `runner.run_visual()` executes visual selection
- [ ] Uses config.runner.command (default: "rails runner")
- [ ] Displays output to user
- [ ] Shows error on failure

---

## Implementation Checklist
- [ ] Create `lua/rails-tools/core/runner.lua`
- [ ] Implement M.run(code) function
- [ ] Implement M.run_prompt() function
- [ ] Implement M.run_visual() function
- [ ] Integrate with ui/terminal.lua
- [ ] Read config.runner.command
- [ ] Register `:Rails runner {code}` subcommand
- [ ] Register `:Rails runner` (no args) subcommand for prompt
- [ ] Create tests for runner module
- [ ] Test code execution
- [ ] Test prompt input
- [ ] Test visual selection

---

## Notes
- Default command: "rails runner"
- Can be overridden via config
- Uses terminal for interactive commands
- Uses vim.notify for quick results

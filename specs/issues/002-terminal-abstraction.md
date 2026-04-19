## **Status:**
- Review: Todo
- PR: Todo

## Metadata
- **Title:** Terminal Abstraction Layer
- **Phase:** Phase 1 — MVP v0.3
- **GitHub Issue:** #13

---

## Description
Implement terminal abstraction layer supporting toggleterm and native terminals.

Steps:
- Check provider config (auto, toggleterm, native)
- If auto: try toggleterm, fallback to native
- If toggleterm: use toggleterm API
- If native: use vim.api.nvim_open_win with appropriate direction
- Support float, horizontal, vertical directions
- Provide toggle and send capabilities

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/ui/terminal.lua`

---

## Acceptance Criteria
- [ ] `terminal.open(cmd, opts)` opens terminal and runs command
- [ ] `terminal.toggle()` toggles terminal window
- [ ] `terminal.send(text)` sends text to active terminal
- [ ] Provider "auto" uses toggleterm if available, else native
- [ ] Provider "toggleterm" uses toggleterm API
- [ ] Provider "native" uses native terminal
- [ ] Direction "float" opens floating window
- [ ] Direction "horizontal" opens bottom split
- [ ] Direction "vertical" opens right split
- [ ] Float size configurable (width, height)
- [ ] Horizontal/vertical size configurable

---

## Implementation Checklist
- [ ] Create `lua/rails-tools/ui/terminal.lua`
- [ ] Implement M.open(cmd, opts) function
- [ ] Implement M.toggle() function
- [ ] Implement M.send(text) function
- [ ] Implement provider detection logic
- [ ] Implement toggleterm backend
- [ ] Implement native terminal backend
- [ ] Support float direction
- [ ] Support horizontal direction
- [ ] Support vertical direction
- [ ] Create tests for terminal module
- [ ] Test each provider
- [ ] Test each direction
- [ ] Test toggle functionality
- [ ] Test send functionality

---

## Notes
- Default provider: "auto"
- Default direction: "float"
- Float opts: width=0.8, height=0.8
- Horizontal size: 15 rows
- Vertical size: 80 columns
- Uses pcall to detect toggleterm availability

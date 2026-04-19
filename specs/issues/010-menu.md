## **Status:**
- Review: Todo
- PR: Todo

## Metadata
- **Title:** Rails Menu
- **Phase:** Phase 1 — MVP v0.2
- **GitHub Issue:** #8

---

## Description
Implement central menu accessible via `:Rails` command.

Steps:
- Create menu module with vim.ui.select
- Define menu items based on enabled modules
- Always show: Alternate File, Find Resource
- Conditional items: View Routes (if routes enabled), Open Console (if console enabled), etc.
- Execute selected action

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/ui/menu.lua`
- Command: `:Rails`

---

## Acceptance Criteria
- [ ] `menu.open()` displays central menu
- [ ] Menu shows "Alternate File" option
- [ ] Menu shows "Find Resource" option
- [ ] Menu shows "View Routes" if modules.routes enabled
- [ ] Menu shows "Open Console" if modules.console enabled
- [ ] Menu shows "Run Code" if modules.runner enabled
- [ ] Menu shows "Run Generator" if modules.generators enabled
- [ ] Menu shows "Run Nearest Spec" if modules.rspec enabled
- [ ] Menu shows "Run Spec File" if modules.rspec enabled
- [ ] Menu shows "Grape Endpoints" if modules.grape enabled
- [ ] Executes selected action correctly

---

## Implementation Checklist
- [ ] Create `lua/rails-tools/ui/menu.lua`
- [ ] Implement M.open() function
- [ ] Define menu items table
- [ ] Implement dynamic menu item filtering based on config
- [ ] Implement action handler
- [ ] Register `:Rails` command in commands.lua
- [ ] Test menu displays correctly
- [ ] Test each menu action

---

## Notes
- Uses vim.ui.select for menu display
- Menu title: "Rails Tools"
- Always available options: Alternate File, Find Resource
- Conditional options based on module enable/disable

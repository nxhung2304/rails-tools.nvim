## **Status:**
- Review: Approved
- PR: Draft

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
- [x] `menu.open()` displays central menu
- [x] Menu shows "Alternate File" option
- [x] Menu shows "Find Resource" option
- [x] Menu shows "View Routes" — moved to L3-010, done there; always shown, since routes is Phase 1 and has no `modules.routes` switch
- [x] Menu shows "Open Console" — always shown (console is Phase 1, there is no `modules.console` flag)
- [x] Menu shows "Run Code" — always shown (runner is Phase 1, there is no `modules.runner` flag)
- [ ] Menu shows "Run Generator" if modules.generators enabled — moved to L4-015
- [ ] Menu shows "Run Nearest Spec" if modules.rspec enabled — moved to L4-014
- [ ] Menu shows "Run Spec File" if modules.rspec enabled — moved to L4-014
- [ ] Menu shows "Grape Endpoints" if modules.grape enabled — moved to L4-017
- [x] Executes selected action correctly

---

## Implementation Checklist
- [x] Create `lua/rails-tools/ui/menu.lua`
- [x] Implement M.open() function
- [x] Define menu items table
- [ ] Implement dynamic menu item filtering based on config — moved to L4-014 (first menu item gated by a module flag)
- [x] Implement action handler
- [x] Register `:Rails` command in commands.lua
- [x] Test menu displays correctly
- [x] Test each menu action

---

## Notes
- Approved with changes: items for features that do not exist yet (routes, generators, rspec, grape) are added by their own tasks, so the menu never lists an action that cannot run. Console and runner are Phase 1 and always on, so their items are always shown. Filtering by `config.modules` lands with the first gated item (L4-014).
- "Find Resource" opens every resource (`finder.find("all")`), same as `:Telescope rails` with no picker name.
- `:Rails` with no subcommand opens the menu.
- Verified: unit tests (`tests/ui/menu_spec.lua`, new case in `tests/commands_spec.lua`) and a headless run on Neovim 0.9.5 in `test-app/`: `:Rails` lists Alternate File, Find Resource, Open Console, Run Code; choosing Alternate File from `app/models/user.rb` opens `spec/models/user_spec.rb`.
- Uses vim.ui.select for menu display
- Menu title: "Rails Tools"
- Always available options: Alternate File, Find Resource
- Conditional options based on module enable/disable


# L4-020. Controller-View Navigation

## Description
Implement specialized navigation between controllers and their associated views.

## Acceptance Criteria
- [ ] Implement `to_view()` - Controller action → View
- [ ] Implement `views_for_controller()` - List all views
- [ ] Implement `from_view()` - View → Controller
- [ ] Implement related files: helper, schema, layout, fixture, migration
- [ ] Implement `related_menu()` - Show available related files
- [ ] Smart view engine detection (.erb, .haml, .slim)
- [ ] Smart format detection (.html, .json, .xml)
- [ ] Handle namespaced controllers
- [ ] Prompt to create missing views
- [ ] Only active when `modules.controller_view = true`

## Implementation Checklist
- [ ] Create `lua/rails-tools/core/controller_view.lua`
- [ ] Register `:R [type]` and `:Rails related [type]` commands
- [ ] Register keymap: `<leader>rv`
- [ ] Create `tests/core/controller_view_spec.lua`

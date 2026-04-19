## **Status:**
- Review: Todo
- PR: Todo

## Metadata
- **Title:** Configuration System
- **Phase:** Phase 1 — MVP v0.1
- **GitHub Issue:** #4

---

## Description
Implement configuration system with default values and user override capability.

Steps:
- Define default configuration structure
- Implement deep merge for user config
- Provide getter for current config
- Support zero-config: works without any parameters

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/config.lua`

---

## Acceptance Criteria
- [ ] `config.setup()` accepts nil or user config table
- [ ] `config.setup()` returns merged configuration
- [ ] Default config includes all modules and their settings
- [ ] `config.get()` returns current or default config
- [ ] User config deeply merges with defaults
- [ ] User can enable/disable individual modules
- [ ] User can customize terminal settings
- [ ] User can customize finder settings
- [ ] User can customize routes cache TTL
- [ ] User can customize keymaps
- [ ] User can add custom alternate mappings

---

## Implementation Checklist
- [ ] Create `lua/rails-tools/config.lua`
- [ ] Define M.defaults with all default settings
- [ ] Implement M.setup(user_config) with deep merge
- [ ] Implement M.get() to return current config
- [ ] Create tests for config module
- [ ] Test nil config (zero-config)
- [ ] Test partial config override
- [ ] Test custom alternate mappings
- [ ] Test module enable/disable

---

## Notes
- Uses vim.tbl_deep_extend for merging
- Default modules: alternate, finder, routes, console, runner enabled
- Phase 2 modules (generators, rspec, grape, test_marker) disabled by default

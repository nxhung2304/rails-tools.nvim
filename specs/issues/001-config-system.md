## **Status:**
- Review: Done
- PR: Done

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
- [x] `config.setup()` accepts nil or user config table
- [x] `config.setup()` returns merged configuration
- [x] Default config includes all modules and their settings
- [x] `config.get()` returns current or default config
- [x] User config deeply merges with defaults
- [x] User can enable/disable individual modules
- [x] User can customize terminal settings
- [x] User can customize finder settings
- [x] User can customize routes cache TTL
- [x] User can customize keymaps
- [x] User can add custom alternate mappings

---

## Implementation Checklist
- [x] Create `lua/rails-tools/config.lua`
- [x] Define M.defaults with all default settings
- [x] Implement M.setup(user_config) with deep merge
- [x] Implement M.get() to return current config
- [x] Create tests for config module
- [x] Test nil config (zero-config)
- [x] Test partial config override
- [x] Test custom alternate mappings
- [x] Test module enable/disable

---

## Notes
- Uses vim.tbl_deep_extend for merging
- Default modules: alternate, finder, routes, console, runner enabled
- Phase 2 modules (generators, rspec, grape, test_marker) disabled by default

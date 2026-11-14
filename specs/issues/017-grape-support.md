## **Status:**
- Review: Todo
- PR: Todo

## Metadata
- **Title:** Grape API Support
- **Phase:** Phase 2 — Expansion v0.6
- **GitHub Issue:** #17

---

## Description
Implement Grape API integration for Rails API projects.

Steps:
- Implement Grape routes parser
- Implement Grape endpoint finder
- Display in Telescope or menu

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/integrations/grape.lua`
- Command: `:Rails grape routes`

---

## Acceptance Criteria
- [x] Parses Grape routes
- [x] Displays Grape endpoints
- [x] Integrates with Telescope
- [x] Shows in Rails menu when enabled

---

## Implementation Checklist
- [x] Create `lua/rails-tools/integrations/grape.lua`
- [x] Implement Grape routes parser
- [x] Implement endpoint finder
- [x] Integrate with Telescope
- [x] Create `tests/integrations/grape_spec.lua`
- [x] Test Grape routes parsing
- [x] Test endpoint display

---

## Notes
- Only active when modules.grape = true
- Requires Grape API detection
- Uses similar pattern to Rails routes
- Decision: routes come from the running app, not from reading `app/api` files.
  `runner.command` runs a Ruby script that walks the Grape APIs mounted in
  `config/routes.rb` and prints verb, full path (mount path + prefix + version),
  `desc` text and the endpoint's file:line (`Grape::Endpoint#source`).
  Checked with Grape 2.4 (test-app) and 4.1.
- Cache: same TTL as Rails routes (`routes.cache_ttl`), `:Rails grape routes!` refreshes it.
- A Grape API that is not mounted in `config/routes.rb` (for example served
  from `config.ru`) is not listed.

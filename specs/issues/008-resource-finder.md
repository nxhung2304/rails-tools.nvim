## **Status:**
- Review: Approved
- PR: Todo

## Metadata
- **Title:** Resource Finder
- **Phase:** Phase 1 — MVP v0.2
- **GitHub Issue:** #6

---

## Description
Implement resource finder to quickly locate and open Rails files by type.

Steps:
- Read resource paths from `config.finder.resources` (each type has `paths`)
- Scan those directories recursively
- Use Telescope if available, otherwise vim.ui.select
- Allow user to select and open file

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/core/finder.lua`
- Resources: models, controllers, views, services, policies, jobs, mailers, serializers, specs, factories

---

## Acceptance Criteria
- [x] `finder.find("models")` opens picker with all models
- [x] `finder.find("controllers")` opens picker with all controllers
- [x] `finder.find("views")` opens picker with all views
- [x] `finder.find("specs")` opens picker with all specs
- [x] `finder.find("services")` opens picker with all services
- [x] `finder.find("jobs")` opens picker with all jobs
- [x] `finder.find("all")` opens picker with all Rails files
- [x] Uses Telescope picker when available
- [x] Falls back to vim.ui.select when Telescope not available
- [x] Opens selected file in current buffer
- [x] A resource type with custom `paths` in config (e.g. services in
      `app/services` + `app/interactors`) lists files from all its paths

---

## Implementation Checklist
- [x] Create `lua/rails-tools/core/finder.lua`
- [x] Read resource paths from `config.finder.resources`
- [x] Implement find(resource_type) function
- [x] Implement directory scanning logic
- [x] Integrate with Telescope (when available)
- [x] Implement vim.ui.select fallback
- [x] Create `tests/core/finder_spec.lua`
- [x] Write tests for each resource type
- [x] Test Telescope integration
- [x] Test vim.ui.select fallback

---

## Notes
- Resource paths follow Rails conventions
- Uses `vim.fs.dir` for file listing (plenary is a test-only dependency)
- Results are cached with 30s TTL

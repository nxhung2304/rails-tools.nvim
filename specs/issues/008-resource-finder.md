## **Status:**
- Review: Todo
- PR: Todo

## Metadata
- **Title:** Resource Finder
- **Phase:** Phase 1 — MVP v0.2
- **GitHub Issue:** #6

---

## Description
Implement resource finder to quickly locate and open Rails files by type.

Steps:
- Define resource paths for different Rails resources
- Scan directory for .rb files (recursive)
- Use Telescope if available, otherwise vim.ui.select
- Allow user to select and open file

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/core/finder.lua`
- Resources: models, controllers, views, services, policies, jobs, mailers, serializers, specs, factories

---

## Acceptance Criteria
- [ ] `finder.find("models")` opens picker with all models
- [ ] `finder.find("controllers")` opens picker with all controllers
- [ ] `finder.find("views")` opens picker with all views
- [ ] `finder.find("specs")` opens picker with all specs
- [ ] `finder.find("services")` opens picker with all services
- [ ] `finder.find("jobs")` opens picker with all jobs
- [ ] `finder.find("all")` opens picker with all Rails files
- [ ] Uses Telescope picker when available
- [ ] Falls back to vim.ui.select when Telescope not available
- [ ] Opens selected file in current buffer

---

## Implementation Checklist
- [ ] Create `lua/rails-tools/core/finder.lua`
- [ ] Define resource_paths table
- [ ] Implement find(resource_type) function
- [ ] Implement directory scanning logic
- [ ] Integrate with Telescope (when available)
- [ ] Implement vim.ui.select fallback
- [ ] Create `tests/core/finder_spec.lua`
- [ ] Write tests for each resource type
- [ ] Test Telescope integration
- [ ] Test vim.ui.select fallback

---

## Notes
- Resource paths follow Rails conventions
- Uses plenary scandir for file listing
- Results are cached with 30s TTL

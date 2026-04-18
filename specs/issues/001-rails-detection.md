## **Status:**
- Review: Approved
- PR: Draft

## Metadata
- **Title:** Rails Detection
- **Phase:** Phase 1 — MVP v0.1
- **GitHub Issue:** #1

---

## Description
Implement Rails project detection module that identifies whether the current directory is a Rails project.

Steps:
- Find root directory by traversing up from cwd
- Check existence of Gemfile AND (bin/rails OR script/rails)
- Cache result by root path
- Return detection result with is_rails flag and root path

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/detectors/rails.lua`

---

## Acceptance Criteria
- [ ] `detector.detect()` returns `{ is_rails = true, root = "/path" }` for valid Rails projects
- [ ] `detector.detect()` returns `nil` for non-Rails projects
- [ ] `detector.root()` returns the Rails project root path
- [ ] `detector.is_rails()` returns boolean
- [ ] Detection results are cached and reused
- [ ] Handles edge cases: monorepos, Rails engines, non-Rails projects

---

## Implementation Checklist
- [ ] Create `lua/rails-tools/detectors/init.lua` - Detector orchestrator
- [ ] Create `lua/rails-tools/detectors/rails.lua` - Rails detection logic
- [ ] Implement `detect()` function
- [ ] Implement `root()` function
- [ ] Implement `is_rails()` function
- [ ] Add caching mechanism
- [ ] Create `tests/detectors/rails_spec.lua`
- [ ] Write tests for valid Rails project detection
- [ ] Write tests for non-Rails project
- [ ] Write tests for edge cases

---

## Notes
- Lazy additional checks: Gemfile contains 'rails' gem, config/application.rb exists, config/routes.rb exists
- If not Rails project, disable all commands and warn once
- Module entry: `lua/rails-tools/detectors/init.lua`

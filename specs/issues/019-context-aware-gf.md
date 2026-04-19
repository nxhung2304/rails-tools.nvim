
# L4-019. Context-Aware gf

## Description
Implement a context-aware `gf` (go to file) command that understands Rails conventions.

## Acceptance Criteria
- [ ] Implement context detection (Treesitter + regex fallback)
- [ ] Implement partial path parser: `"shared/header"` → `app/views/shared/_header.html.erb`
- [ ] Implement fixture finder: `:users` → `test/fixtures/users.yml`
- [ ] Implement migration finder: `User` → latest `db/migrate/*_create_users.rb`
- [ ] Implement route finder: route name → controller#action
- [ ] Support visual selection for complex paths
- [ ] Detect view engine: .erb, .haml, .slim
- [ ] Detect format: .html, .json, .xml
- [ ] Fallback to default `gf` if no Rails context
- [ ] Only active when `modules.gf = true`

## Implementation Checklist
- [ ] Create `lua/rails-tools/core/gf.lua`
- [ ] Implement core logic
- [ ] Create `tests/core/gf_spec.lua`

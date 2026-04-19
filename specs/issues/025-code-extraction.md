
# L5-025. Code Extraction

## Description
Implement code extraction tools to refactor Rails code into concerns, helpers, or partials.

## Acceptance Criteria
- [ ] Implement `extract_visual(filename, mode)` function
- [ ] Implement partial extraction (views)
- [ ] Implement concern extraction (models/controllers)
- [ ] Implement helper extraction
- [ ] Detect and prompt for local variables
- [ ] Support .erb, .haml, .slim engines
- [ ] Only active when `modules.extractor = true`

## Implementation Checklist
- [ ] Create `lua/rails-tools/core/extractor.lua`
- [ ] Register `:Extract {filename}` and `:Rails extract {filename}` commands
- [ ] Create `tests/core/extractor_spec.lua`


# L5-027. Optional Integrations

## Description
Implement integrations with other popular Neovim plugins and tools.

## Acceptance Criteria
- [ ] Database Integration (vim-dadbod): Browser, console, schema commands
- [ ] Telescope Integration (Enhanced): Schemas, migrations, helpers, fixtures pickers
- [ ] Snippet Integration: Model, controller, migration, view templates
- [ ] Test Integration (neotest): Adapters for RSpec and Minitest
- [ ] Add `config.integrations` section

> Note: Rails-attribute-aware go-to-definition and `nvim-cmp` completion
> moved to `021-schema-inspector.md` — they depend on the same schema/
> annotate parsing as the schema inspector, not on a generic LSP/cmp
> integration layer, so tracking them here duplicated the work.

## Implementation Checklist
- [ ] Create `lua/rails-tools/integrations/detector.lua`
- [ ] Create `lua/rails-tools/integrations/manager.lua`
- [ ] Implement each integration module
- [ ] Create tests for each integration

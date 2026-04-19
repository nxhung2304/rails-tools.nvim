
# L5-027. Optional Integrations

## Description
Implement integrations with other popular Neovim plugins and tools.

## Acceptance Criteria
- [ ] Database Integration (vim-dadbod): Browser, console, schema commands
- [ ] LSP Integration: Enhanced go-to-definition, Rails-specific code actions
- [ ] Telescope Integration (Enhanced): Schemas, migrations, helpers, fixtures pickers
- [ ] Snippet Integration: Model, controller, migration, view templates
- [ ] Test Integration (neotest): Adapters for RSpec and Minitest
- [ ] Completion Integration (nvim-cmp): Context-aware completion
- [ ] Add `config.integrations` section

## Implementation Checklist
- [ ] Create `lua/rails-tools/integrations/detector.lua`
- [ ] Create `lua/rails-tools/integrations/manager.lua`
- [ ] Implement each integration module
- [ ] Create tests for each integration

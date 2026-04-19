
# L5-026. Syntax Highlighting

## Description
Enhance Ruby/Rails syntax highlighting for Neovim.

## Acceptance Criteria
- [ ] Define Rails keyword groups (Associations, Validations, Callbacks, Helpers, Macros)
- [ ] Create Treesitter queries for Rails methods
- [ ] Implement regex fallback for older Neovim
- [ ] Support user-defined keywords via config
- [ ] Add `config.syntax` settings

## Implementation Checklist
- [ ] Create `lua/rails-tools/core/syntax.lua`
- [ ] Create `syntax/rails.vim`
- [ ] Create `after/syntax/ruby/rails.vim`
- [ ] Create `tests/core/syntax_spec.lua`

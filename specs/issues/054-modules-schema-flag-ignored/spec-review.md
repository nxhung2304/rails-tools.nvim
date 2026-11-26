---
GitHub Issue: #54
Status: READY
---

## Summary
The plan gates the schema cache, LSP `K`/`gd` override and cmp source on `modules.schema` in `init.lua`, and blocks the Telescope `grape` picker at call time when `modules.grape` is off. Every factual claim was checked against the code and holds. No blocking gaps; a few small wording and test-coverage notes.

## Well-Defined
- Config defaults are correct: `modules.schema = true` (`config.lua:42`), `modules.grape = false` (`config.lua:45`).
- Augroup names are correct: `rails_tools_schema_cache` (`core/schema.lua:160`), `rails_tools_lsp_schema` (`integrations/lsp.lua:99`).
- Only `init.lua:21,23,24` calls the three `setup()` functions; no other caller in `lua/` or `plugin/`.
- `M.exports` is built once at require time (`telescope/init.lua:40`, via `build_exports()` reading `config.get()`), and `lua/telescope/_extensions/rails.lua` requires it directly, so the "check at call time" choice is justified.
- Warning text matches `commands.lua:40` exactly.
- Test layout follows plenary convention (`tests/init_spec.lua`, `tests/telescope/init_spec.lua`); the outer `before_each` in `init_spec.lua` clears `rails-tools` and `rails-tools.integrations.cmp`, so `setup_done` and cmp's `registered` flag reset as claimed.
- The existing grape Telescope test change is an intended spec change, listed in Notes, assertions kept.
- Checklist maps 1:1 to the acceptance criteria; issue AC "not exported (or shows warning)" is satisfied by the warning option.

## Issues Found
### K/gd remap is asserted only indirectly
> `no rails_tools_schema_cache and no rails_tools_lsp_schema augroup exist, so K/gd are never remapped`

**Problem:** The test proves the LspAttach autocmd is absent, which is the only place `K`/`gd` are mapped (`integrations/lsp.lua:97-116`). This is a valid proxy, but the AC reads as if `K`/`gd` themselves are checked.
**Suggest:** Keep as is, or add a short note that augroup absence is the chosen proof.

### Merge-conflict note with BF-055 is likely inaccurate
> `the conflict is in the same lines`

**Problem:** BF-055 edits line 15 (`setup_done = true`) and adds a line after line 25; BF-054 replaces lines 21-24. Line 25 stays unchanged between the two hunks, so git will likely merge without a textual conflict (guess, not run). The real check is semantic: BF-055's tests call `setup()` with defaults, which still run schema/lsp/cmp.
**Suggest:** Reword to "may or may not conflict textually; after rebasing, rerun `tests/init_spec.lua`".

### Line references depend on merge order
> `replace lines 21-24`

**Problem:** If BF-055 lands first, the line numbers shift by one.
**Suggest:** None needed; the code block makes the target unambiguous.

## Score (9/10)
- AC: ✅
- Checklist: ✅
- Design: ✅ (no `specs/rules/`; design tokens not applicable)

## Status
- [x] READY
- [ ] PENDING — needs clarification

## **Status:**
- Review: Todo
- PR: Todo

## Metadata
- **Title:** Schema Display
- **Phase:** Phase 3 — Polish v0.8
- **Depends on:** [021-schema-inspector.md](021-schema-inspector.md) (`core/schema.lua`)

---

## Description
Give the schema data parsed in `021-schema-inspector.md` a way to be
browsed directly, for when a dev wants to see a whole table's structure
without editor-integration features (hover/completion/gd) being enough —
e.g. checking a table they don't have a model open for.

This is independent, optional UI on top of an already-working parser; it
is not a dependency of hover/completion/gd and can ship separately.

Steps:
- Reuse `core/schema.lua` (from 021) for table data — no new parsing
- Format a table's columns/types/indexes for display
- Expose via `:Rails schema {table}` and a Telescope picker

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/core/schema.lua` (from 021) — no changes needed
  beyond what 021 already exposes
- Module: `lua/rails-tools/ui/schema_display.lua` — formats one table's
  data into lines for a floating window / `vim.ui.select` style buffer
- Command: `:Rails schema {table}` — display a single table's structure
  (requires `commands.lua` / `:Rails` dispatch to exist — see
  `010-menu.md` / `011-keymaps.md`)
- Telescope extension: `:Telescope rails schema` — list tables, preview
  structure, `<CR>` to open full display
- Config: `modules.schema` (shared with 021 — same on/off switch)

---

## Acceptance Criteria
- [ ] `:Rails schema {table}` displays table structure
- [ ] Shows column names and types
- [ ] Shows indexes
- [ ] Integrates with Telescope (`:Telescope rails schema`)
- [ ] Falls back to `vim.ui.select` when Telescope is not available
- [ ] Shows a clear error for an unknown table name

---

## Implementation Checklist
- [ ] Create `lua/rails-tools/ui/schema_display.lua`
- [ ] Implement table formatting (columns, types, indexes)
- [ ] Wire `:Rails schema {table}` command
- [ ] Integrate with Telescope picker
- [ ] Create `tests/ui/schema_display_spec.lua`
- [ ] Test table formatting
- [ ] Test unknown-table error handling

---

## Notes
- Blocked on `commands.lua` / `:Rails` dispatch existing (see
  `010-menu.md`, `011-keymaps.md`) unless shipped as its own standalone
  `:RailsSchema` command in the meantime
- No new schema/annotate parsing here — reuses `021-schema-inspector.md`'s
  `core/schema.lua` as-is

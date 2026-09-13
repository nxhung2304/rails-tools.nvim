## **Status:**
- Review: Todo
- PR: Todo

## Metadata
- **Title:** Schema Inspector
- **Phase:** Phase 3 — Polish v0.8
- **GitHub Issue:** #19

---

## Description
Implement schema inspector to view database table structures, and use that
same schema data to power ActiveRecord-attribute-aware editor features:
hover documentation, `nvim-cmp` completion, and go-to-definition — since
none of those are real Ruby methods an LSP can see.

Steps:
- Parse `db/schema.rb` as the canonical, always-up-to-date source of
  columns/types/indexes per table
- Also parse the `annotate` gem's schema comment block in each
  `app/models/**/*.rb` file, when present, and map `model → table`
  from its `# Table name: xxx` line
- Merge: column list/types come from `db/schema.rb`; when a model file has
  an annotate block for a column, **prefer jumping to that comment line**
  over `db/schema.rb` (annotate lives right next to the code the dev is
  reading; `db/schema.rb` is the fallback when annotate is absent/stale)
- Display table structures (columns, types, indexes)
- Expose the parsed data to:
  - Hover (`K`) on `receiver.column` or a bare `column` inside the owning
    model — show type/constraints instead of LSP's "No information available"
  - `nvim-cmp` source — complete attribute names after `receiver.`,
    scoped to the inferred model (not every column in the project)
  - Go-to-definition (`gd`) on a column — jump to the annotate comment line
    if present, else the `db/schema.rb` column line, else the
    `create_table` line

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/core/schema.lua` — parsing + cache, returns per
  table: `{ columns = { name = { type, signature, indexes } }, source }`
- Module: `lua/rails-tools/core/model_context.lua` — receiver → model
  inference shared by hover/cmp/gd:
  - `self` / bare identifier (no receiver) → model of the current buffer
    (only valid inside `app/models/**/*.rb`)
  - `<var>.column` → camelize/singularize `<var>`, match against known
    model names; on no match, fall back to the current buffer's model
    (never a project-wide "every model with this column" guess) unless the
    lookup itself has no receiver context at all (see completion below)
- Integration: `lua/rails-tools/integrations/cmp.lua` — registers the
  `rails_schema` cmp source (gated by `modules.schema` / cmp being present)
- Integration: hover and `gd` are wired in the existing LSP `on_attach`
  path, buffer-local for `ruby`/`eruby`, falling back to
  `vim.lsp.buf.hover()` / `vim.lsp.buf.definition()` when no schema match
- Command: `:Rails schema {table}` — display a single table's structure
- Config: `modules.schema` (default `true` — this is core Rails ergonomics,
  not an optional integration like rspec/grape)

---

## Acceptance Criteria
- [ ] Parses `db/schema.rb` (columns, types, indexes) as the primary source
- [ ] Parses `annotate` schema comment blocks in `app/models/**/*.rb`
      (column signatures + `# Table name:` → model/table mapping)
- [ ] `:Rails schema {table}` displays table structure
- [ ] Shows column names and types
- [ ] Shows indexes
- [ ] Integrates with Telescope (`:Telescope rails schema`)
- [ ] Hover (`K`) on `receiver.column` / bare `column` inside its own model
      shows the column's type + full signature (default/null/etc.), not
      "No information available"
- [ ] Hover falls back to normal LSP hover when the identifier isn't a
      known column for the resolved model
- [ ] `nvim-cmp` source completes column names after `receiver.`, scoped to
      the model inferred from `receiver` — never lists columns from
      unrelated models that happen to share the same column name
- [ ] `gd` on a column jumps to, in priority order: (1) the annotate
      comment line in the owning model file, (2) the matching line in
      `db/schema.rb`, (3) the `create_table` line if the column is
      implicit (`id`, `created_at`, `updated_at`)
- [ ] `gd`/hover fall back to `vim.lsp.buf.definition()` /
      `vim.lsp.buf.hover()` for anything that isn't a recognized column
- [ ] Model inference handles: `self`, bare identifier (current buffer's
      own model only), `snake_case_var`, simple pluralization
      (`users` → `User`)

---

## Implementation Checklist
- [ ] Create `lua/rails-tools/core/schema.lua` (db/schema.rb parser)
- [ ] Create `lua/rails-tools/core/annotate.lua` (annotate block parser:
      signatures + table name + comment line location, per model)
- [ ] Create `lua/rails-tools/core/model_context.lua` (receiver → model
      inference, reused by hover/cmp/gd)
- [ ] Integrate with `lua/rails-tools/cache.lua` for schema + annotate
      caching (TTL, keyed by Rails root, invalidate on `db/schema.rb` /
      model file write)
- [ ] Implement table display + `:Rails schema {table}` command
- [ ] Integrate with Telescope picker
- [ ] Create `lua/rails-tools/integrations/cmp.lua` (`rails_schema` source)
- [ ] Wire hover (`K`) override into the ruby/eruby `on_attach`
- [ ] Wire go-to-definition (`gd`) override into the ruby/eruby `on_attach`
- [ ] Create `tests/core/schema_spec.lua`
- [ ] Create `tests/core/annotate_spec.lua`
- [ ] Create `tests/core/model_context_spec.lua`
- [ ] Test schema.rb parsing
- [ ] Test annotate block parsing (signature + table name + line location)
- [ ] Test model inference (self, bare word, var name, pluralization,
      unresolvable → current-buffer-model-only, never project-wide)
- [ ] Test cmp completion scoping (no cross-model leakage)
- [ ] Test gd priority order (annotate → schema.rb column → create_table)
- [ ] Test display functionality

---

## Notes
- Caches schema and annotate parsing for performance (TTL, keyed by Rails
  root; `test-app/` fixture should include an annotated model and a
  non-annotated one to cover both paths)
- Supports both schema.rb and migrations as documented sources for the
  underlying table data, but annotate comments (when present) win for
  the actual jump target since they sit next to the code being read
- Bare-identifier (no receiver) lookups must **only** resolve against the
  current buffer's own model — this was a real bug during prototyping:
  treating every bare word as "show every model with a matching column"
  caused false positives outside model files

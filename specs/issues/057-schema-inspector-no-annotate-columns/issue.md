[ISSUE-#57] Schema Inspector shows no columns for models without an annotate block
GitHub Issue: #57
State: OPEN
Labels: bug
Assignees: 
Source: GitHub

## Problem
The table name of a model comes only from the annotate gem's `# Table name:` comment. A model without that comment is still listed as a known model, but its table is never looked up in `db/schema.rb`, so it has zero columns: hover, `gd` and completion show nothing even though the table exists.

## Evidence
- `lua/rails-tools/core/schema.lua:128-135` — `schema_table = ann.table_name and schema_tables[ann.table_name]`; with no annotate block `ann.table_name` is nil.
- `core/annotate.lua:56-66` still adds every model file (so the model is in `known_models`, just with empty columns).

## Acceptance criteria
- [ ] When there is no annotate block, the table name is inferred from the model name (pluralized, snake_case, namespace-aware once the namespace issue is fixed), and an explicit `self.table_name = "..."` in the model file wins if present.
- [ ] Columns for such models come from `db/schema.rb`, with `gd` jumping to the schema line.
- [ ] Annotated models behave as before.
- [ ] Regression test with an un-annotated model fixture.

## Notes
Depends on the pluralize/singularize fix for irregular names.

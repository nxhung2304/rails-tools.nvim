# Risks to test - #57

Source: ~/.ai-metrics/orchestrator/20261118-risk-057.md (checked against main 82bb64e)

## Missing from the spec

1. Stale annotate columns mixed in when `self.table_name` differs from the annotate table
   - Case: annotate says `users` (with column `email`) and the model sets `self.table_name = "orders"`.
   - Effect: table name becomes `orders`, but `merge_columns` still takes the annotate columns of `users` (core/schema.lua:84-105), so hover/completion shows columns that do not exist.
   - Reachable now: yes, when the annotate block is older than `self.table_name`.
   - Test: in the "Explicit beats annotate" test, add the line `#  email  :string` to the annotate block. Assert `columns.email` is nil and `columns.user_id` exists.

## Possible risks (guesses, low confidence)

2. Multi-database: a secondary-DB model matches a same-named table in `db/schema.rb`
   - `schema.load` reads only `db/schema.rb` (core/schema.lua:54-61), so an inferred name can match the primary DB table and show wrong columns.
   - Reachable now: only in apps using `connects_to` with `db/<name>_schema.rb` and a table name shared with the primary DB.
   - Test: temp root with `users` in `db/schema.rb` and a secondary-DB model of the same name; check the result.

3. Non-model files in `app/models` get columns of a same-named table
   - `annotate.scan` takes every file except concerns (core/annotate.lua:53-70), so a PORO, a namespace module (`admin.rb` with table `admins`) or an STI child can match.
   - Effect: extra columns in hover/completion only. Before this change these had 0 columns.
   - Test: temp root with `app/models/search.rb` (PORO) and a `searches` table; check the result.

4. `self.table_name` is taken from the first matching line in the whole file
   - The pattern `^%s*self%.table_name%s*=` does not know which class owns the line. Nested classes, several classes in one file, or a line inside a heredoc / `=begin` can win.
   - Test: model with a nested class that sets a different `self.table_name`; assert the outer class name is used.

## Checked, no risk
- Concurrency, timeout, retry, observability: not applicable (synchronous local Lua).
- Cache staleness after `rails db:migrate` outside Neovim (up to 300s TTL): pre-existing, same as annotated models.
- "Go to schema" and file lookup by table still use the old logic: known out-of-scope item, follow-up.

[ISSUE-#56] Namespaced models lose their namespace (Admin::User and User collide)
GitHub Issue: #56
State: OPEN
Labels: bug
Assignees: 
Source: GitHub

## Problem
Model names are built from the file's basename only. `app/models/admin/user.rb` becomes `User`, the same key as `app/models/user.rb`. In the schema scan the later file overwrites the earlier one, so hover, `gd` and completion can show columns from the wrong model.

## Evidence
- `lua/rails-tools/core/model_context.lua:67-73` — `model_for_path` matches `app/models/.-([%w_]+)%.rb$`, keeping only the last segment.
- `lua/rails-tools/core/annotate.lua:60` — `scan` uses `fnamemodify(file, ":t:r")` (basename) as the key into `by_model`.

## Related: safe navigation `&.` loses the receiver
`context.word_and_receiver("user&.email", ...)` returns receiver `nil` (checked headless), so `user&.email` is treated like a bare `email`: inside a model file hover/`gd` resolve to the open model's column, outside a model file nothing is shown. The cmp receiver pattern (`integrations/cmp.lua:22`) also fails on `user&.`, so no completion is offered.
- `lua/rails-tools/integrations/context.lua:37-43`

## Acceptance criteria
- [x] `model_for_path("app/models/admin/user.rb")` returns `Admin::User`; `app/models/user.rb` still returns `User`.
- [x] `annotate.scan` keys models by full namespaced name; two models with the same basename both appear.
- [x] Decide and document how `app/models/concerns/**` is handled (today concerns are scanned as models too).
- [x] `user&.email` resolves receiver `user` for hover, `gd` and completion.
- [x] Regression tests for these functions with a namespaced fixture and a `&.` case.

# Risks to test - #61

No design-breaking risk. The change is a pure, synchronous string function.

## 1. Migration lookup now uses the irregular plural (verified by risk report)
- The migrations lookup also uses the table name guessed from the model, so for a model without a schema annotation it now searches for `people` instead of `persons`. Unit tests cover the function only, not this caller.
- Test (manual): app with `app/models/person.rb` (no annotation) and a migration with `create_table :people`. Open the model, run `:Rails related`. Expect the migration to be listed.

## 2. Receiver `news` no longer maps to a `New` model (verified headless)
- Only matters for an app that has a `New` model and no `News` model: receiver `news` used to resolve to `New`, now falls back to the current model or nothing.
- Test: `infer_model("news", { New = true }, nil)` before and after the change.

## Accepted differences from ActiveSupport
Each is deliberate (whole-word matching, shorter list) and rare.
1. `people` is not handled when passed to the plural function: `people` gives `peoples`. No caller passes a plural.
2. Words that only end in an irregular word differ: ActiveSupport gives `human` -> `humen` and `salesperson` -> `salespeople`; this change gives `humans` and `salespersons`. A `Human` model with default Rails inflections has table `humen`, which the plugin will not find.
3. Only five uncountable words are covered (not `rice`, `money`, `fish`, `sheep`, `jeans`, `police`). Adding one later is one line.

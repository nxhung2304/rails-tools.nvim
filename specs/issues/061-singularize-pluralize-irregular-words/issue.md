[ISSUE-#61] singularize/pluralize give wrong results for common and irregular words
GitHub Issue: #61
State: OPEN
Labels: bug
Assignees: 
Source: GitHub

## Related
- [Implement plan](./implement.md)

## Problem
The inflection helpers only have a few suffix rules and no irregular table, so table/model/controller names are wrong for many real names. These helpers feed model inference, related-file lookup and table-to-model paths.

## Examples (traced from the current rules)
- `singularize("movies")` → `movy` (expected `movie`)
- `singularize("people")` → `people` (expected `person`); `pluralize("person")` → `persons`
- `singularize("children")` → `children`; `pluralize("child")` → `childs`
- Uncountables: `singularize("news")` → `new`, `singularize("series")` → `sery`

## Evidence
- `lua/rails-tools/core/model_context.lua:13-35`
- Callers: `core/related_files.lua:157,211,246`, `core/rails_paths.lua:183`, and `infer_model` in `model_context.lua`.

## Acceptance criteria
- [x] Irregular table (at least person/people, child/children, man/men, woman/women, mouse/mice, ox/oxen) and uncountables (equipment, information, series, species, news...).
- [ ] Rules for `-ies` that keep `movie`-type words correct, and other common ActiveSupport rules.
- [x] Unit tests listing each pair in both directions.

## Scope decided
- Follows story BF-061 only: irregular table, uncountables, `movie`-type `-ies` words, unit tests both directions.
- "Other common ActiveSupport rules" from the GitHub criteria is out of scope for this task and goes to a follow-up issue (see implement.md Decisions). The PR uses `Refs #61`, not `Closes #61`.

---
GitHub Issue: #58
Status: READY
---

## Summary
Plan (stop caching misses + `clear_cache()` + README + regression test) matches the code on `main` (4d02907). Line numbers in implement.md are correct. No blocking gap; a few small accuracy and coverage points below.

## Well-Defined
- Root cause verified: `rails.lua:39-41` returns any non-nil entry, `rails.lua:52` stores `false`.
- Checklist steps 1-6 name exact files, lines and code; README anchor lines 191-195 and story lines 395-397 are correct.
- Regression test (step 3) fails on current code and passes after the fix.
- Existing positive-cache tests (`rails_spec.lua:62-70`, `90-101`) are unaffected; other spec files reset `package.loaded["rails-tools.detectors.rails"]`, so no test relies on a stored `false`.
- Test change (step 5) is a title rename only; assertions unchanged.

## Issues Found
### Caller list is incomplete
> Every module resolves the root through `rails.root()` (grep `rails.root`): ...

**Problem:** Omits `detectors/test_framework.lua:37`, `detectors/grape.lua:43`, `detectors/init.lua:9,14,19` and `health.lua:209` uses `rails_detector.root()` (not `rails.root`). Conclusion is unchanged.
**Suggest:** Add the missing callers for completeness.

### issue.md evidence line is off by two
> `rails.lua:50` stores `false` for a miss.

**Problem:** Actual line is 52 (implement.md already uses 52).
**Suggest:** Fix when ticking the acceptance criteria in step 8.

### story.md item wording vs chosen fix
> `specs/story.md:395` Do not cache negative results forever (re-check on `DirChanged` or after a TTL)

**Problem:** The chosen fix (no negative caching) is neither of the two options in story.md; issue.md allows it. Ticking it in step 8 is fine, but the wording will not describe what was done.
**Suggest:** Note in step 8 whether the story line is reworded or just ticked.

### Hot-path cost of uncached misses covers cmp only
> Non-Rails folder with `modules.cmp` on ...

**Problem:** The LSP `K`/`gd` override (`integrations/lsp.lua:13` → `schema.resolve` → `rails.root()`) and every `:Rails` action in a non-Rails folder now also walk up to `/` per call. Same negligible cost, but the risk list names only cmp.
**Suggest:** Widen the risk line to "every root lookup in a non-Rails folder".

### Stale `test_framework` case is narrower than stated
> run `:Rails alternate` in a folder before `rails new` → ... caches `false` for that folder

**Problem:** It only stays stale when the Rails root equals the folder already cached (e.g. `rails new .` in cwd). With `rails new myapp` the new root is a different key and detection is fresh.
**Suggest:** State the condition in the risk line.

## Score (9/10)
- AC: ✅
- Checklist: ✅
- Design: ✅ (N/A, no UI)

## Status
- [x] READY
- [ ] PENDING — needs clarification

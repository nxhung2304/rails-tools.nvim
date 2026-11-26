# Risks to test - #54

No architectural risk was missed by the spec. Two low-likelihood risks (guesses):

## 1. Merge note with BF-055 may point the wrong way (medium confidence)
- BF-055 changes `init.lua:15` and adds a line after `init.lua:25`. #54 replaces `init.lua:21-24`. Line 25 sits between and is unchanged, so git will likely merge without a text conflict, and the author may skip re-running tests after the rebase.
- Semantically safe: BF-055 tests call `setup()` with defaults (schema = true) and stub `core.gf`, so they do not touch the schema flag.
- Test: rebase the second branch onto the first, then run `make test-file FILE=tests/init_spec.lua`.

## 2. Calling `integrations.lsp.setup()` by hand also bypasses the flag (low confidence)
- The gate lives only in `init.lua`, so a direct call to the LSP, cmp or schema setup skips `modules.schema`.
- No real entry point does this today (grep finds only `init.lua:21,23,24` and tests); no document tells users to call them.
- Test: not needed.

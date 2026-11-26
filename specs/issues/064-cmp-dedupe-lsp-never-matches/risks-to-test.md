# Risks to test (#64)

1. Neovim 0.9.5 path was checked from source only (in-process server command, synchronous initialize, unnamed buffer URI).
   Test: CI job on v0.9.5. If it fails, look at the attach step first (the wait assertion message points to it).
2. If detaching a client fails on 0.9.5, the client stays attached and is reused by the next test (same name and root dir).
   Test: the detach assertion in tests/integrations/cmp_spec.lua; confirm on the CI v0.9.5 job.
3. The stop_client deprecation notice is printed on current stable (v0.12.6).
   Test: run `make test-file FILE=tests/integrations/cmp_spec.lua` on stable and in the CI stable job; the job must still pass.
4. A string value for dedupe_with_lsp now errors during completion (not reachable via documented config, which uses a list).
   Test: set dedupe_with_lsp = "ruby_lsp" and trigger completion; decide on a guard or accept.

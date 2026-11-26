# Risks to test - 058 Rails detector negative cache

1. Cost of re-checking non-Rails folders (not measured)
   - Test: open Neovim in a deep non-Rails folder on a slow disk (network mount), open a Ruby file with `modules.cmp` on, type a receiver, and press `K` or `gd` repeatedly. Expect no visible lag.
   - Test (automated): stub `vim.fn.filereadable` in a spec, call `rails.root()` twice on a non-Rails folder, and confirm the count grows by one walk per call (expected).
2. Test framework detector stays stale (not fixed here)
   - Test: open Neovim in an empty folder, run `:Rails alternate`, create a Minitest Rails app in that folder from another terminal, run `:Rails alternate` again. Expect it still assumes rspec until restart. Confirm, then file a follow-up issue.
3. Positive results are never invalidated
   - Test: open a Rails project, run any `:Rails` command, delete `bin/rails`, run it again (still treated as Rails). Run `:lua require("rails-tools.detectors.rails").clear_cache()` and run again. Expect "not Rails".
4. Parent folder of the temp dir is a Rails root (test assumption)
   - Test: run `make test` on a machine where the temp folder is not inside a Rails app. Expect the new tests pass.
5. Grape detector cache
   - Test: run `:checkhealth rails-tools` in a non-Rails folder, create the project, run it again. Expect the Rails check updates and Grape shows no stale output.
6. Core fix end to end
   - Test: open Neovim in an empty folder, run `:Rails routes` (expect a "not Rails" warning), create `Gemfile` and `bin/rails`, run `:Rails routes` again. Expect it finds the project without restart.

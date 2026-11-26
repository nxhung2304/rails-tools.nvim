# Risks to test - BF-060 (#60), PR #70

1. Old default strings in tests: run `make test-file FILE=tests/core/console_spec.lua` (and `make test`); expect 0 failures.
2. Grape runner message with no user runner command: config.setup without runner, cause "cannot be started"; expect message contains `bin/rails runner` (Grape test added).
3. README example: override lines must stay commented out so copying does not pin the executable. Review README diff.
4. story.md default-config block: `grep -n "rails console" specs/story.md`; expect no old defaults.
5. Console reuse: open console, hide it, run `:Rails console` again; expect same terminal shown, no replace prompt.
6. `bin/rails` without executable bit: `:Rails console` fails by design; setting `console.command` fixes it. Manual only.
7. Default vs global `rails` behaviour in a sample app: compare `rails runner 'p $0'` and `bin/rails runner 'p $0'`. Manual only.
8. BF-059 merge conflict in `config.lua` defaults: whichever merges second rebases and reruns `tests/config_spec.lua`.

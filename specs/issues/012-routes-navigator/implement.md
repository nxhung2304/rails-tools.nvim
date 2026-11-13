# Implement: Routes Navigator (L3-010, issue #10)

## Real output samples
Captured from `test-app` (Rails 7.1.6) with `bin/rails routes --expanded`, paths replaced by `/app`:
- `tests/fixtures/routes/expanded.txt`: normal app routes, namespaced `admin/users#index`, an inline proc route, framework routes (Action Mailbox, Active Storage) whose source location is a gem.
- `tests/fixtures/routes/expanded_with_engine.txt`: a copy of test-app with `mount Blog::Engine`, a mounted lambda and `redirect("/new")`.

What the samples show:
- Each route is a block that starts with `--[ Route N ]---`. Fields are `Name | value`; an empty value is `Prefix            | ` (trailing space).
- Mounted engine routes come after a `[ Routes for Blog::Engine ]` line and numbering restarts at 1. Their URI is relative to the mount point (`/posts`, not `/blog/posts`).
- Non-navigable `Controller#Action` values: `Blog::Engine`, `Inline handler (Proc/Lambda)`, `redirect(301, /new)`. A mount has an empty `Verb`.
- Success: exit 0, but stderr can still hold warnings (`config.eager_load is set to nil...`).
- Failure (syntax error in `config/routes.rb`): exit 1, empty stdout, 54 lines of stderr; the first 6 lines are the eager_load warning, the real error follows.
- Empty `routes.rb`: exit 0, framework routes are still listed.
- Takes about 2.5s on test-app.

## Decisions
- D1. `M.parse(output)` splits the output block by block and returns `{ name, verb, path, controller_action, source_location, engine }` per route. `engine` is set for routes under a `[ Routes for X ]` line and is shown in the picker so their relative URI is not misread.
- D2. A route is navigable only when `controller_action` matches `path/to/controller#action` (lowercase, digits, `_`, `/`). Everything else is listed but `goto_action` shows a notice.
- D3. `controller#action` maps to `app/controllers/<controller>_controller.rb`. When that file does not exist (engine or gem controller), show a notice with the expected path instead of opening an empty buffer.
- D4. The method line is the first line matching `def <action>` followed by a non-identifier character. If none is found, open the file at the top and show a notice.
- D5. The command is `config.routes.command .. " " .. config.routes.args`, run with `vim.fn.jobstart` (via shell) in the Rails root, stdout and stderr buffered. Callbacks are wrapped in `vim.schedule` before touching the UI.
- D6. Loading indicator: a "Rails: loading routes..." notice when the command starts.
- D7. Failure: notice with the exit code and the first 20 non-empty stderr lines (the real error comes after the eager_load warning). A `jobstart` failure (command not executable) shows a notice right away.
- D8. Cache: one entry per Rails root, TTL `config.routes.cache_ttl`. `cache.lua` only has a synchronous `get(key, builder)`, so add `peek(key)` (fresh value or nil) and `set(key, value)`.
- D9. Only one job per root. `show()` while a job runs shows "still loading" and starts nothing. `refresh()` stops the running job, clears the cache and starts a new one, so a hung command can be recovered with `:Rails routes!`. The "still loading" notice names `:Rails routes!`.
- D13. Each job's callbacks check that it is still the current job for its root. A job stopped by `refresh()` exits with a non-zero code; without this check it would show a false failure and clear the loading state of the new job.
- D10. Picker: Telescope when available (reuses `config.finder.provider`), otherwise `vim.ui.select`. Telescope export `routes` forces the Telescope provider, as the resource pickers do.
- D11. Entry points: `:Rails routes` → `show()`, `:Rails routes!` → `refresh()`, menu item "View Routes" after "Find Resource", keymap `<leader>ro` → `<Cmd>Rails routes<CR>`.
- D12. No routes parsed (exit 0, nothing in stdout) → "Rails: no routes found" notice.

## Risks accepted (from risk-issue)
- The picker opens when the command finishes, in whatever window is current then (the user may have moved on).
- A command that hangs keeps "still loading" until `:Rails routes!`; there is no timeout.
- Routes are up to `cache_ttl` seconds old after editing `config/routes.rb`; `:Rails routes!` reloads.
- Telescope is not installed in the test environment, so the Telescope picker is tested with a stubbed telescope only.

## Out of scope
- Grape routes (L4-017).
- Jumping to `Source Location` in `config/routes.rb` (not asked by the spec).
- Telescope previewer for routes.

# Risks to test - #59

- Hover/definition show stale schema data (up to 5 minutes) when `modules.schema = false` and the user maps the public hover/definition functions themselves. Accepted as a known limitation. Test: turn schema off, map the hover function, edit `db/schema.rb` and save, press the key right away, expect the old columns.
- Faked `LspAttach` with a `group` on Neovim v0.9.5 (low confidence, guess). Test: run `make test` on CI, which includes the v0.9.5 matrix entry.

## Related
- [issue.md](issue.md)
- [implement.md](implement.md)
- [comment.log](comment.log)

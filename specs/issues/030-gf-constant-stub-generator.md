## **Status:**
- Review: Todo
- PR: Todo

## Metadata
- **Title:** gf Constant Stub Generator
- **Phase:** Phase 1 — MVP (extends `019-context-aware-gf.md`'s `gf.lua`)
- **GitHub Issue:** #34

---

## Description
`019-context-aware-gf.md` covers `gf` on partial paths, fixtures,
migrations, and routes — not a plain Ruby constant reference like
`Api::V1::Auth::VertifyOtp.new(...)` where the class doesn't exist yet.
Today, pressing `gf` on such a constant falls through to Neovim's default
`gf` and fails, or silently does nothing.

This issue adds: cursor on a Ruby constant (optionally namespaced via
`::`) → resolve the file path by Rails convention (CamelCase segment →
snake_case, `::` → `/`, relative to the app's autoload root, e.g.
`app/`) → if the file exists, open it like a normal `gf`; if it doesn't,
prompt to create it with a nested-module stub.

Decided in discussion (see conversation, not saved separately):
- Stub uses **nested modules**, not compact `class Api::V1::Auth::VertifyOtp`
  — matches Rails generator's `module_namespacing` convention and the
  project's own code style (confirmed from the triggering code sample).
- Stub body is **empty** (`class VertifyOtp; end`) — no guessed
  `initialize`/`call` methods, since the class's actual pattern (service
  object, form object, etc.) isn't known from a bare reference.

---

## Design
- No wireframe needed
- Module: `lua/rails-tools/core/gf.lua` (new logic alongside
  `019-context-aware-gf.md`'s partial-path/fixture/migration/route
  resolution, not a separate module)
- Reuses the create-prompt pattern already in `core/alternate.lua`'s
  `open_or_create()` (`vim.fn.input("Create ... ? (y/N): ")` +
  `vim.fn.mkdir(..., "p")` + `vim.fn.writefile(...)`), but needs a new
  stub-content writer instead of writing an empty file
- Namespace → path mapping: split constant on `::`, `CamelCase` →
  `snake_case` for each segment, join with `/`
- Autoload-root resolution (for a namespaced constant, e.g.
  `Api::V1::Auth::VertifyOtp`): don't guess a fixed root. Search existing
  directories under `app/*/<namespace-path-minus-class>` (e.g.
  `app/*/api/v1/auth/`) — the namespace almost always already has sibling
  files there.
  - Exactly one match → use it.
  - Multiple matches → `vim.ui.select` (same pattern as
    `core/alternate.lua`'s multi-choice picker).
  - No match (new namespace, or a bare constant with no `::` at all) →
    fall back to default `gf` and create nothing. Guessing a root wrong
    produces a stub in the wrong layout, which is worse than doing
    nothing.

---

## Acceptance Criteria
- [ ] Cursor on a bare constant (`VertifyOtp`) or namespaced constant
      (`Api::V1::Auth::VertifyOtp`) and `gf` resolves the expected file
      path by Rails convention
- [ ] If the resolved file exists, `gf` opens it (same as default `gf`
      behavior)
- [ ] If the resolved file does not exist, prompts
      `Create <path> ? (y/N)` before creating anything
- [ ] On confirmation, creates intermediate directories and writes a
      nested-module stub matching the constant's namespace depth, then
      opens the new file
- [ ] On decline, does nothing (no file/directory created)
- [ ] Falls back to default `gf` if the cursor isn't on a constant
- [ ] For a namespaced constant, resolves the autoload root by matching
      an existing `app/*/<namespace-path>` directory; prompts via
      `vim.ui.select` when more than one matches
- [ ] For a bare constant (no `::`) or a namespace with no existing
      directory match, falls back to default `gf` and creates nothing
- [ ] Only active when `modules.gf = true` (per `019-context-aware-gf.md`)

---

## Implementation Checklist
- [ ] Add constant-detection to `lua/rails-tools/core/gf.lua` (Treesitter
      node type for Ruby constants, regex fallback per
      `019-context-aware-gf.md`'s existing approach)
- [ ] Implement namespace → path resolver (CamelCase → snake_case per
      segment, `::` → `/`)
- [ ] Implement nested-module stub content generator
- [ ] Wire stub creation into the existing create-prompt flow (reuse or
      extract `core/alternate.lua`'s `open_or_create` pattern)
- [ ] Implement autoload-root resolver: scan `app/*/<namespace-path>`
      for existing directory matches
- [ ] Add tests to `tests/core/gf_spec.lua`
- [ ] Test existing-file open path
- [ ] Test missing-file create-and-stub path
- [ ] Test decline-creation path (no side effects)
- [ ] Test nested-module stub content for 1, 2, and 3+ namespace levels

---

## Notes
- `specs/story.md` now has an `L4-030` entry near `L4-019`.

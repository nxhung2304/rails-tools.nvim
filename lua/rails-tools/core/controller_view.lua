local rails = require("rails-tools.detectors.rails")
local rails_paths = require("rails-tools.core.rails_paths")
local rails_file_kind = require("rails-tools.core.rails_file_kind")
local related_files = require("rails-tools.core.related_files")

local M = {}

local SELECT_PROMPT = "Rails related"

---Related file types, in the order the menu lists them.
---@type string[]
M.TYPES = related_files.TYPES

---What kind of Rails file a path relative to the Rails root is, nil when it has no related files.
---@type fun(relative_file: string): RailsFileKind|nil
M.kind_of = rails_file_kind.kind_of

---Public controller action whose `def` is the nearest one at or above a line.
---@type fun(lines: string[], lnum: integer): string|nil
M.action_at = rails_file_kind.action_at

---Related files of one type for a file, and why nothing was found.
---@type fun(ctx: RelatedContext, related_type: string): RelatedEntry[], RelatedMissing|nil
M.find = related_files.find

---Every related file that exists for a file, in `M.TYPES` order.
---@type fun(ctx: RelatedContext): RelatedEntry[]
M.related = related_files.related

---@return RelatedContext|nil
local function current_context()
  local file = vim.api.nvim_buf_get_name(0)
  local root
  if file ~= "" then
    root = rails.root(vim.fn.fnamemodify(file, ":p:h"))
  end
  if not root then
    vim.notify("Rails: not a Rails project", vim.log.levels.WARN)
    return nil
  end
  return {
    root = root,
    relative_file = rails_paths.relative_path(root, file),
    lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
    cursor_lnum = vim.api.nvim_win_get_cursor(0)[1],
  }
end

---@param root string
---@param entry RelatedEntry
local function open_entry(root, entry)
  vim.cmd.edit(vim.fn.fnameescape(root .. "/" .. entry.path))
  if entry.lnum then
    vim.api.nvim_win_set_cursor(0, { entry.lnum, 0 })
  end
end

---@param root string
---@param entries RelatedEntry[]
---@param with_type boolean label entries as `<type>: <path>`
local function open_entries(root, entries, with_type)
  if #entries == 1 then
    open_entry(root, entries[1])
    return
  end
  vim.ui.select(entries, {
    prompt = SELECT_PROMPT,
    format_item = function(entry)
      return with_type and ("%s: %s"):format(entry.type, entry.path) or entry.path
    end,
  }, function(choice)
    if choice then
      open_entry(root, choice)
    end
  end)
end

---@param root string
---@param relative string
local function create_view(root, relative)
  local answer = vim.fn.input(("Create %s ? (y/N): "):format(relative))
  if not answer:lower():match("^y") then
    return
  end
  local absolute = root .. "/" .. relative
  vim.fn.mkdir(vim.fn.fnamemodify(absolute, ":h"), "p")
  vim.fn.writefile({}, absolute)
  vim.cmd.edit(vim.fn.fnameescape(absolute))
end

---@param ctx RelatedContext
---@param related_type string
local function open_found(ctx, related_type)
  local entries, missing = M.find(ctx, related_type)
  if #entries > 0 then
    open_entries(ctx.root, entries, false)
  elseif missing and missing.create_path then
    create_view(ctx.root, missing.create_path)
  elseif missing then
    vim.notify(missing.message, vim.log.levels.INFO)
  end
end

---Open the related file of `related_type` for the current buffer; several matches are picked from a list.
---@param related_type string one of `M.TYPES`
function M.open_type(related_type)
  if not vim.tbl_contains(M.TYPES, related_type) then
    vim.notify(("Rails: usage: :Rails related [%s]"):format(table.concat(M.TYPES, "|")), vim.log.levels.ERROR)
    return
  end
  local ctx = current_context()
  if ctx then
    open_found(ctx, related_type)
  end
end

---Open the view of the controller action at the cursor, or pick one of the controller's views.
function M.to_view()
  M.open_type("view")
end

---Open the controller (or mailer) of the current view at its action.
function M.from_view()
  M.open_type("controller")
end

---Switch between a controller action and its view.
function M.toggle()
  local ctx = current_context()
  if not ctx then
    return
  end
  local file_kind = M.kind_of(ctx.relative_file)
  if file_kind and file_kind.kind == "controller" then
    open_found(ctx, "view")
  elseif file_kind and file_kind.kind == "view" then
    open_found(ctx, "controller")
  else
    vim.notify("Rails: not a controller or view", vim.log.levels.INFO)
  end
end

---Pick one of the existing related files of the current buffer.
function M.related_menu()
  local ctx = current_context()
  if not ctx then
    return
  end
  local entries = M.related(ctx)
  if #entries == 0 then
    vim.notify("Rails: no related files for this file", vim.log.levels.INFO)
    return
  end
  open_entries(ctx.root, entries, true)
end

return M

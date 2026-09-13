local schema = require("rails-tools.core.schema")
local model_context = require("rails-tools.core.model_context")

local M = {}

---@return string|nil
local function receiver_before_cursor(cursor_before_line)
  return cursor_before_line:match("@?([%a_][%w_]*)%.[%w_]*$")
end

---@param name string
---@param resolved_column ResolvedColumn
---@param model string
---@return table cmp.CompletionItem-shaped table
local function make_item(name, resolved_column, model)
  local cmp = require("cmp")
  return {
    label = name,
    kind = cmp.lsp.CompletionItemKind.Field,
    detail = resolved_column.signature:match("^:(%S+)") or "",
    documentation = {
      kind = "markdown",
      value = ("`%s`  %s"):format(model, resolved_column.signature),
    },
  }
end

local source = {}

function source.new()
  return setmetatable({}, { __index = source })
end

function source:get_trigger_characters()
  return { "." }
end

function source:is_available()
  return vim.bo.filetype == "ruby" or vim.bo.filetype == "eruby"
end

function source:complete(params, callback)
  local receiver = receiver_before_cursor(params.context.cursor_before_line)
  if not receiver then
    callback({ items = {}, isIncomplete = false })
    return
  end

  local resolved = schema.resolve()
  if not resolved then
    callback({ items = {}, isIncomplete = false })
    return
  end

  local current_model = model_context.model_for_path(vim.api.nvim_buf_get_name(0))
  local model = model_context.infer_model(receiver, resolved.known_models, current_model)
  local items = {}
  if model then
    local model_data = resolved.models[model]
    if model_data then
      for name, resolved_column in pairs(model_data.columns) do
        table.insert(items, make_item(name, resolved_column, model))
      end
    end
  end

  callback({ items = items, isIncomplete = false })
end

local registered = false

---Register the `rails_schema` nvim-cmp source. No-ops (returns false)
---when nvim-cmp isn't installed. Safe to call more than once: only
---registers the source once, since `cmp.register_source` adds a new
---source instance on every call instead of replacing the previous one.
---@return boolean registered
function M.setup()
  if registered then
    return true
  end
  local ok, cmp = pcall(require, "cmp")
  if not ok then
    return false
  end
  cmp.register_source("rails_schema", source.new())
  registered = true
  return true
end

return M

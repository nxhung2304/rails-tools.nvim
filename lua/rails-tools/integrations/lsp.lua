local schema = require("rails-tools.core.schema")
local model_context = require("rails-tools.core.model_context")
local context = require("rails-tools.integrations.context")

local M = {}

---@param receiver string|nil
---@param column string
---@param current_model string|nil
---@param root string|nil
---@return string|nil, ResolvedColumn|nil
local function resolve_column(receiver, column, current_model, root)
  local resolved = schema.resolve(root)
  if not resolved then
    return nil, nil
  end
  local model = receiver and model_context.infer_model(receiver, resolved.known_models, current_model) or current_model
  if not model then
    return nil, nil
  end
  local model_data = resolved.models[model]
  local col = model_data and model_data.columns[column]
  if not col then
    return nil, nil
  end
  return model, col
end

---Hover documentation for a `receiver.column` (or bare `column` inside its
---own model) ActiveRecord attribute. Returns nil when it isn't a
---recognized column, so callers can fall back to normal LSP hover.
---@param receiver string|nil
---@param column string
---@param current_model string|nil
---@param root string|nil
---@return string[]|nil lines for a markdown floating window
function M.hover_lines(receiver, column, current_model, root)
  local model, col = resolve_column(receiver, column, current_model, root)
  if not col then
    return nil
  end
  return { ("**%s**"):format(column), ("`%s`  %s"):format(model, col.signature) }
end

---Where `gd` should jump for a `receiver.column` (or bare `column`)
---ActiveRecord attribute. Returns nil when it isn't a recognized column.
---@param receiver string|nil
---@param column string
---@param current_model string|nil
---@param root string|nil
---@return {file: string, lnum: integer, col: integer}|nil
function M.definition_location(receiver, column, current_model, root)
  local _, col = resolve_column(receiver, column, current_model, root)
  return col and col.location or nil
end

local function current_model()
  return model_context.model_for_path(vim.api.nvim_buf_get_name(0))
end

---@param bufnr integer
local function attach_hover(bufnr)
  vim.keymap.set("n", "K", function()
    local receiver, word = context.at_cursor()
    if word then
      local lines = M.hover_lines(receiver, word, current_model())
      if lines then
        vim.lsp.util.open_floating_preview(lines, "markdown", { border = "rounded", focusable = false })
        return
      end
    end
    vim.lsp.buf.hover()
  end, { buffer = bufnr, desc = "Hover Documentation (Rails-aware)" })
end

---@param bufnr integer
local function attach_goto_definition(bufnr)
  vim.keymap.set("n", "gd", function()
    local receiver, word = context.at_cursor()
    if word then
      local loc = M.definition_location(receiver, word, current_model())
      if loc then
        vim.cmd("edit " .. vim.fn.fnameescape(loc.file))
        vim.api.nvim_win_set_cursor(0, { loc.lnum, loc.col })
        vim.cmd("normal! zz")
        return
      end
    end
    vim.lsp.buf.definition()
  end, { buffer = bufnr, desc = "Go to Definition (Rails-aware)" })
end

---Wire the Rails-aware `K` / `gd` overrides for ruby/eruby buffers that
---have an LSP client attached. Falls back to the normal
---`vim.lsp.buf.hover()` / `vim.lsp.buf.definition()` for anything that
---isn't a recognized ActiveRecord column.
function M.setup()
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("rails_tools_lsp_schema", { clear = true }),
    callback = function(args)
      local filetype = vim.bo[args.buf].filetype
      if filetype ~= "ruby" and filetype ~= "eruby" then
        return
      end
      -- Neovim fires `LspAttach` before running the client config's own
      -- `on_attach` (see Client:on_attach in $VIMRUNTIME/lua/vim/lsp/client.lua),
      -- so a host that also sets `K`/`gd` in `on_attach` would clobber these
      -- right after this callback returns. Deferring to the next tick makes
      -- ours the last write, regardless of registration order.
      vim.schedule(function()
        attach_hover(args.buf)
        attach_goto_definition(args.buf)
      end)
    end,
  })
end

return M

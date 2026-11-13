local rails = require("rails-tools.detectors.rails")
local terminal = require("rails-tools.ui.terminal")

local M = {}

local GENERATE_COMMAND = "rails generate"
local PROMPT = "Rails generate: "

---@return string|nil
local function project_root()
  if vim.bo.buftype == "" then
    local file = vim.api.nvim_buf_get_name(0)
    local file_root = file ~= "" and rails.root(vim.fn.fnamemodify(file, ":p:h")) or nil
    if file_root then
      return file_root
    end
  end

  return rails.root()
end

---Run `rails generate {args}` in the plugin terminal
---@param args string|nil generator name and its arguments, e.g. "model User name:string"
function M.run(args)
  local trimmed_args = args and vim.trim(args) or ""
  if trimmed_args == "" then
    vim.notify("Rails: no generator given", vim.log.levels.WARN)
    return
  end

  local root = project_root()
  if not root then
    vim.notify("Rails: not a Rails project", vim.log.levels.WARN)
    return
  end

  if not terminal.confirm_replace() then
    return
  end

  terminal.open(GENERATE_COMMAND .. " " .. trimmed_args, { cwd = root })
end

---Ask for generator arguments and run `rails generate` with them
function M.run_prompt()
  vim.ui.input({ prompt = PROMPT }, function(input)
    if input == nil then
      return
    end

    M.run(input)
  end)
end

return M

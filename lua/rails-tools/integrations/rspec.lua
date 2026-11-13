local config = require("rails-tools.config")
local rails = require("rails-tools.detectors.rails")
local terminal = require("rails-tools.ui.terminal")

local M = {}

local SPEC_FILE_SUFFIX = "_spec.rb"

---@class RailsToolsSpecRun
---@field cmd string
---@field cwd string

---@type RailsToolsSpecRun|nil
local last_run

---@return {root: string, path: string}|nil
local function current_spec_file()
  local file = vim.bo.buftype == "" and vim.api.nvim_buf_get_name(0) or ""
  if not vim.endswith(file, SPEC_FILE_SUFFIX) then
    vim.notify("Rails: not a spec file", vim.log.levels.WARN)
    return nil
  end

  local absolute_file = vim.fn.fnamemodify(file, ":p")
  local root = rails.root(vim.fn.fnamemodify(absolute_file, ":h"))
  if not root then
    vim.notify("Rails: not a Rails project", vim.log.levels.WARN)
    return nil
  end

  return { root = root, path = absolute_file:sub(#root + 2) }
end

---@param spec_run RailsToolsSpecRun
local function open_in_terminal(spec_run)
  if not terminal.confirm_replace() then
    return
  end

  if config.get().rspec.save_last then
    last_run = spec_run
  end
  terminal.open(spec_run.cmd, { cwd = spec_run.cwd })
end

---@param root string
---@param target string
local function run_target(root, target)
  open_in_terminal({ cmd = config.get().rspec.command .. " " .. vim.fn.shellescape(target), cwd = root })
end

---Run the example or group at the cursor line of the current spec file
function M.run_nearest()
  local spec = current_spec_file()
  if not spec then
    return
  end

  run_target(spec.root, spec.path .. ":" .. vim.fn.line("."))
end

---Run every example in the current spec file
function M.run_file()
  local spec = current_spec_file()
  if not spec then
    return
  end

  run_target(spec.root, spec.path)
end

---Run the last spec command again
function M.run_last()
  if not last_run then
    vim.notify("Rails: no spec to re-run", vim.log.levels.WARN)
    return
  end

  open_in_terminal(last_run)
end

return M

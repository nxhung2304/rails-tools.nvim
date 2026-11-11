local config = require("rails-tools.config")
local rails = require("rails-tools.detectors.rails")
local terminal = require("rails-tools.ui.terminal")

local M = {}

local console_root = nil

---@return string
local function console_command()
  return config.get().console.command
end

---@param root string
---@return boolean
local function is_console_active(root)
  return terminal.active_cmd() == console_command() and console_root == root
end

---Open the Rails console, or show the running one if it is hidden
function M.open()
  local root = rails.root()
  if not root then
    vim.notify("Rails: not a Rails project", vim.log.levels.WARN)
    return
  end

  if not is_console_active(root) then
    terminal.open(console_command(), { cwd = root })
    console_root = root
    return
  end

  if not terminal.is_visible() then
    terminal.show()
  end
end

---Hide or show the running Rails console, opening it when none is running
function M.toggle()
  if is_console_active(rails.root()) and terminal.is_visible() then
    terminal.toggle()
    return
  end

  M.open()
end

return M

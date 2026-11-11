local finder = require("rails-tools.core.finder")

local M = {}

local RESOURCE_PICKERS = { "models", "controllers", "views", "services", "specs" }

---@param resource_type string
---@return fun(picker_opts: table|nil)
local function resource_picker(resource_type)
  return function(picker_opts)
    finder.find(resource_type, { provider = "telescope", picker_opts = picker_opts })
  end
end

---Pickers exposed as `:Telescope rails <name>` and `require("telescope").extensions.rails.<name>`
---@type table<string, fun(picker_opts: table|nil)>
M.exports = {}

for _, resource_type in ipairs(RESOURCE_PICKERS) do
  M.exports[resource_type] = resource_picker(resource_type)
end

M.exports.grape = function()
  vim.notify("Rails: Grape routes picker is not available yet", vim.log.levels.INFO)
end

---Load the `rails` Telescope extension when telescope.nvim is installed
---@return boolean loaded
function M.setup()
  local has_telescope, telescope = pcall(require, "telescope")
  if not has_telescope then
    return false
  end
  return (pcall(telescope.load_extension, "rails"))
end

return M

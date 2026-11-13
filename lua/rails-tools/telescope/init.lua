local config = require("rails-tools.config")
local finder = require("rails-tools.core.finder")

local M = {}

local ALL_RESOURCES = "all"
local DEFAULT_PICKER = "rails"
local EXTENSION_NAME = "rails"

---@param resource_type string
---@return fun(picker_opts: table|nil)
local function resource_picker(resource_type)
  return function(picker_opts)
    finder.find(resource_type, { provider = "telescope", picker_opts = picker_opts })
  end
end

---@return table<string, fun(picker_opts: table|nil)>
local function build_exports()
  local exports = {}
  for resource_type, resource in pairs(config.get().finder.resources) do
    if type(resource) == "table" and type(resource.paths) == "table" then
      exports[resource_type] = resource_picker(resource_type)
    end
  end

  exports[DEFAULT_PICKER] = resource_picker(ALL_RESOURCES)
  exports.routes = function(picker_opts)
    require("rails-tools.core.routes").show({ provider = "telescope", picker_opts = picker_opts })
  end
  exports.grape = function()
    vim.notify("Rails: Grape routes picker is not available yet", vim.log.levels.INFO)
  end
  return exports
end

---Pickers exposed as `:Telescope rails <name>` and `require("telescope").extensions.rails.<name>`:
---one per `finder.resources` type, `rails` for every resource, `routes`, and a `grape` placeholder
---@type table<string, fun(picker_opts: table|nil)>
M.exports = build_exports()

---Load the `rails` Telescope extension when telescope.nvim is already loaded, so setup never loads it early
---@return boolean loaded
function M.setup()
  local telescope = package.loaded["telescope"]
  if not telescope then
    return false
  end

  local loaded, err = pcall(telescope.load_extension, EXTENSION_NAME)
  if not loaded then
    vim.notify(("Rails: could not load Telescope extension: %s"):format(err), vim.log.levels.WARN)
  end
  return loaded
end

return M

local config = require("rails-tools.config")

local M = {}

local MENU_TITLE = "Rails Tools"

---@class RailsToolsMenuItem
---@field label string
---@field action fun()
---@field module? string config.modules key that must be true to show the item

---@type RailsToolsMenuItem[]
local MENU_ITEMS = {
  {
    label = "Alternate File",
    action = function()
      require("rails-tools.core.alternate").open()
    end,
  },
  {
    label = "Find Resource",
    action = function()
      require("rails-tools.core.finder").find("all")
    end,
  },
  {
    label = "View Routes",
    action = function()
      require("rails-tools.core.routes").show()
    end,
  },
  {
    label = "Open Console",
    action = function()
      require("rails-tools.core.console").open()
    end,
  },
  {
    label = "Run Code",
    action = function()
      require("rails-tools.core.runner").run_prompt()
    end,
  },
  {
    label = "Run Nearest Spec",
    module = "rspec",
    action = function()
      require("rails-tools.integrations.rspec").run_nearest()
    end,
  },
  {
    label = "Run Spec File",
    module = "rspec",
    action = function()
      require("rails-tools.integrations.rspec").run_file()
    end,
  },
}

---@return RailsToolsMenuItem[]
local function enabled_items()
  local enabled_modules = config.get().modules
  return vim.tbl_filter(function(item)
    return not item.module or enabled_modules[item.module]
  end, MENU_ITEMS)
end

---Show the Rails Tools menu and run the chosen action
function M.open()
  vim.ui.select(enabled_items(), {
    prompt = MENU_TITLE,
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if choice then
      vim.schedule(choice.action)
    end
  end)
end

return M

local M = {}

local MENU_TITLE = "Rails Tools"

---@class RailsToolsMenuItem
---@field label string
---@field action fun()

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
}

---Show the Rails Tools menu and run the chosen action
function M.open()
  vim.ui.select(MENU_ITEMS, {
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

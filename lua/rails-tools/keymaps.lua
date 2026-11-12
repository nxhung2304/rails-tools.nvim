local config = require("rails-tools.config")

local M = {}

---@class RailsToolsKeymapBinding
---@field suffix string
---@field desc string
---@field action fun()

---@type RailsToolsKeymapBinding[]
local DEFAULT_BINDINGS = {
  {
    suffix = "r",
    desc = "Rails: menu",
    action = function()
      require("rails-tools.ui.menu").open()
    end,
  },
  {
    suffix = "a",
    desc = "Rails: alternate file",
    action = function()
      require("rails-tools.core.alternate").open()
    end,
  },
  {
    suffix = "f",
    desc = "Rails: find resource",
    action = function()
      require("rails-tools.core.finder").find("all")
    end,
  },
  {
    suffix = "c",
    desc = "Rails: console",
    action = function()
      require("rails-tools.core.console").open()
    end,
  },
  {
    suffix = "x",
    desc = "Rails: run code",
    action = function()
      require("rails-tools.core.runner").run_prompt()
    end,
  },
}

---Register the default normal-mode keymaps under `config.keymaps.prefix`.
---Does nothing when `config.keymaps.enabled` is false.
function M.setup()
  local keymaps_config = config.get().keymaps
  if not keymaps_config.enabled then
    return
  end

  for _, binding in ipairs(DEFAULT_BINDINGS) do
    vim.keymap.set("n", keymaps_config.prefix .. binding.suffix, binding.action, {
      silent = true,
      desc = binding.desc,
    })
  end
end

return M

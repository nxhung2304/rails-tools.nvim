local config = require("rails-tools.config")

local M = {}

---@class RailsToolsKeymapBinding
---@field suffix string
---@field desc string
---@field action string|fun()

---@type RailsToolsKeymapBinding[]
local DEFAULT_BINDINGS = {
  {
    suffix = "r",
    desc = "Rails: menu",
    action = "<Cmd>Rails<CR>",
  },
  {
    suffix = "a",
    desc = "Rails: alternate file",
    action = "<Cmd>Rails alternate<CR>",
  },
  {
    suffix = "f",
    desc = "Rails: find resource",
    action = function()
      require("rails-tools.core.finder").find("all")
    end,
  },
  {
    suffix = "o",
    desc = "Rails: routes",
    action = "<Cmd>Rails routes<CR>",
  },
  {
    suffix = "c",
    desc = "Rails: console",
    action = "<Cmd>Rails console<CR>",
  },
  {
    suffix = "x",
    desc = "Rails: run code",
    action = "<Cmd>Rails runner<CR>",
  },
}

---Register the default normal-mode keymaps under `config.keymaps.prefix`.
---Does nothing when `config.keymaps.enabled` is false.
function M.setup()
  local keymaps_config = config.get().keymaps
  if type(keymaps_config) ~= "table" or not keymaps_config.enabled then
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

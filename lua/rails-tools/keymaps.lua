local config = require("rails-tools.config")

local M = {}

---@class RailsToolsKeymapBinding
---@field suffix string
---@field desc string
---@field action string|fun()
---@field module? string config.modules key that must be true to register the keymap

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
  {
    suffix = "s",
    desc = "Rails: run nearest spec",
    action = "<Cmd>Rails spec nearest<CR>",
    module = "rspec",
  },
  {
    suffix = "S",
    desc = "Rails: run spec file",
    action = "<Cmd>Rails spec file<CR>",
    module = "rspec",
  },
  {
    suffix = "g",
    desc = "Rails: run generator",
    action = "<Cmd>Rails generate<CR>",
    module = "generators",
  },
}

---Register the default normal-mode keymaps under `config.keymaps.prefix`.
---Does nothing when `config.keymaps.enabled` is false.
---Keymaps of an opt-in module are registered only when that module is enabled.
function M.setup()
  local keymaps_config = config.get().keymaps
  if type(keymaps_config) ~= "table" or not keymaps_config.enabled then
    return
  end

  local enabled_modules = config.get().modules
  for _, binding in ipairs(DEFAULT_BINDINGS) do
    if not binding.module or enabled_modules[binding.module] then
      vim.keymap.set("n", keymaps_config.prefix .. binding.suffix, binding.action, {
        silent = true,
        desc = binding.desc,
      })
    end
  end
end

return M

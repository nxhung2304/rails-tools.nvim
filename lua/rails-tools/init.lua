local config = require("rails-tools.config")
local commands = require("rails-tools.commands")

local M = {}

local setup_done = false

---Entry point called by the user's plugin manager config. Zero-config by
---default; deep-merges a user-supplied `opts` over the defaults.
---@param opts table|nil
function M.setup(opts)
  if setup_done then
    return
  end
  setup_done = true

  config.setup(opts)
  commands.setup()

  require("rails-tools.core.schema").setup()
  require("rails-tools.integrations.lsp").setup()
  require("rails-tools.integrations.cmp").setup()
end

return M

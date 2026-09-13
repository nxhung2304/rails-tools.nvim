local M = {}

local subcommands = {
  alternate = function()
    require("rails-tools.core.alternate").open()
  end,
}

local registered = false

---Register the `:Rails {subcommand}` user command with a dispatch table.
---Safe to call more than once; only registers the command once.
function M.setup()
  if registered then
    return
  end
  registered = true

  vim.api.nvim_create_user_command("Rails", function(opts)
    local subcommand = opts.fargs[1]
    if not subcommand then
      return
    end

    local handler = subcommands[subcommand]
    if not handler then
      vim.notify(("Rails: unknown subcommand '%s'"):format(subcommand), vim.log.levels.ERROR)
      return
    end

    handler()
  end, {
    nargs = "*",
    desc = "rails-tools.nvim command dispatcher",
  })
end

return M

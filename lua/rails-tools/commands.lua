local M = {}

local subcommands = {
  alternate = function()
    require("rails-tools.core.alternate").open()
  end,
  console = function()
    require("rails-tools.core.console").open()
  end,
  runner = function(opts)
    local runner = require("rails-tools.core.runner")

    if opts.args ~= "" then
      runner.run(opts.args)
    elseif opts.range > 0 then
      local is_last_visual_range = opts.line1 == vim.fn.line("'<") and opts.line2 == vim.fn.line("'>")
      if is_last_visual_range then
        runner.run_visual()
      else
        runner.run_lines(opts.line1, opts.line2)
      end
    else
      runner.run_prompt()
    end
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

    handler({
      args = opts.args:match("^%s*%S+%s*(.-)%s*$"),
      range = opts.range,
      line1 = opts.line1,
      line2 = opts.line2,
    })
  end, {
    nargs = "*",
    range = true,
    desc = "rails-tools.nvim command dispatcher",
  })
end

return M

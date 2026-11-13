local M = {}

local SPEC_USAGE = "Rails: usage: :Rails spec nearest|file|last"

local SPEC_ACTIONS = {
  nearest = "run_nearest",
  file = "run_file",
  last = "run_last",
}

local subcommands = {
  alternate = function()
    require("rails-tools.core.alternate").open()
  end,
  console = function()
    require("rails-tools.core.console").open()
  end,
  generate = function(opts)
    if not require("rails-tools.config").get().modules.generators then
      vim.notify("Rails: generators are disabled, set modules.generators = true", vim.log.levels.WARN)
      return
    end

    local generators = require("rails-tools.core.generators")
    if opts.args ~= "" then
      generators.run(opts.args)
    else
      generators.run_prompt()
    end
  end,
  find = function(opts)
    require("rails-tools.core.finder").find(opts.args)
  end,
  routes = function()
    require("rails-tools.core.routes").show()
  end,
  ["routes!"] = function()
    require("rails-tools.core.routes").refresh()
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
  spec = function(opts)
    if not require("rails-tools.config").get().modules.rspec then
      vim.notify("Rails: RSpec runner is disabled, set modules.rspec = true", vim.log.levels.WARN)
      return
    end

    local action = SPEC_ACTIONS[opts.args]
    if not action then
      vim.notify(SPEC_USAGE, vim.log.levels.ERROR)
      return
    end

    require("rails-tools.integrations.rspec")[action]()
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
      require("rails-tools.ui.menu").open()
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

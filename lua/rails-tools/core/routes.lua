local cache = require("rails-tools.cache")
local config = require("rails-tools.config")
local rails = require("rails-tools.detectors.rails")

local M = {}

local PICKER_TITLE = "Rails routes"
local MAX_ERROR_LINES = 20
local VERB_COLUMN_WIDTH = 7
local CONTROLLERS_DIR = "app/controllers/"
local CONTROLLER_FILE_SUFFIX = "_controller.rb"

local FIELD_NAMES = {
  ["Prefix"] = "name",
  ["Verb"] = "verb",
  ["URI"] = "path",
  ["Controller#Action"] = "controller_action",
  ["Source Location"] = "source_location",
}

---@class RailsToolsRoute
---@field name string route name (`Prefix`), "" when the route has none
---@field verb string HTTP verb, "" for mounts
---@field path string URI pattern
---@field controller_action string `controller#action`, or what Rails prints for mounts, procs and redirects
---@field source_location? string where the route is defined (Rails 7.1+)
---@field engine? string engine name for routes listed under `[ Routes for <engine> ]`

---@class RailsToolsRoutesShowOpts
---@field provider? "auto"|"telescope"|"native" overrides `finder.provider`
---@field picker_opts? table passed to the Telescope picker

local routes_cache = cache.new()

---@type table<string, integer>
local running_jobs = {}

---@return string|nil
local function project_root()
  if vim.bo.buftype == "" then
    local file = vim.api.nvim_buf_get_name(0)
    local file_root = file ~= "" and rails.root(vim.fn.fnamemodify(file, ":p:h")) or nil
    if file_root then
      return file_root
    end
  end

  return rails.root()
end

---@return string|nil
local function rails_root_or_warn()
  local root = project_root()
  if not root then
    vim.notify("Rails: not a Rails project", vim.log.levels.WARN)
  end
  return root
end

---Parse the output of `rails routes --expanded`, one route per `--[ Route N ]--` block
---@param output string
---@return RailsToolsRoute[]
function M.parse(output)
  local parsed = {}
  local engine = nil
  local route = nil

  for _, line in ipairs(vim.split(output, "\n", { plain = true })) do
    local engine_name = line:match("^%[ Routes for (.-) %]%s*$")
    if engine_name then
      engine = engine_name
      route = nil
    elseif line:match("^%-%-%[ Route %d+ %]") then
      route = { engine = engine }
      table.insert(parsed, route)
    elseif route then
      local label, value = line:match("^(%S.-)%s*|%s?(.*)$")
      local field = label and FIELD_NAMES[label]
      if field then
        route[field] = vim.trim(value)
      end
    end
  end

  return parsed
end

---Map `controller#action` to the controller file (relative to the Rails root) and the action name
---@param controller_action string
---@return {path: string, action: string}|nil nil when the route has no controller action
function M.controller_location(controller_action)
  local target = controller_action:match("^%S+") or ""
  local controller, action = target:match("^([%l%d_/]+)#([%w_]+[?!]?)$")
  if not controller then
    return nil
  end

  return { path = CONTROLLERS_DIR .. controller .. CONTROLLER_FILE_SUFFIX, action = action }
end

---@param lines string[]
---@param action string
---@return integer|nil
local function def_line(lines, action)
  local def_pattern = "^%s*def%s+" .. vim.pesc(action) .. "%f[^%w_?!]"
  for line_number, line in ipairs(lines) do
    if line:match(def_pattern) then
      return line_number
    end
  end
  return nil
end

---@param root string
---@param route RailsToolsRoute
local function open_route(root, route)
  local location = M.controller_location(route.controller_action)
  if not location then
    vim.notify(("Rails: %s has no controller action to open"):format(route.controller_action), vim.log.levels.INFO)
    return
  end

  local file_path = root .. "/" .. location.path
  if vim.fn.filereadable(file_path) == 0 then
    vim.notify(("Rails: %s not found"):format(location.path), vim.log.levels.INFO)
    return
  end

  local opened, err = pcall(vim.cmd.edit, vim.fn.fnameescape(file_path))
  if not opened then
    vim.notify(("Rails: %s"):format(err), vim.log.levels.ERROR)
    return
  end

  local line_number = def_line(vim.api.nvim_buf_get_lines(0, 0, -1, false), location.action)
  if not line_number then
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.notify(("Rails: def %s not found in %s"):format(location.action, location.path), vim.log.levels.INFO)
    return
  end
  vim.api.nvim_win_set_cursor(0, { line_number, 0 })
end

---Open the controller of a route at `def <action>`
---@param route RailsToolsRoute
function M.goto_action(route)
  local root = rails_root_or_warn()
  if not root then
    return
  end

  open_route(root, route)
end

---@param route RailsToolsRoute
---@return string
local function format_route(route)
  local padded_verb = ("%-" .. VERB_COLUMN_WIDTH .. "s"):format(route.verb or "")
  local text = ("%s %s  %s"):format(padded_verb, route.path or "", route.controller_action or "")
  if route.name and route.name ~= "" then
    text = ("%s  (%s)"):format(text, route.name)
  end
  if route.engine then
    text = ("[%s] %s"):format(route.engine, text)
  end
  return text
end

---@param provider string
---@return boolean
local function use_telescope(provider)
  if provider == "native" then
    return false
  end

  local has_telescope = pcall(require, "telescope")
  if not has_telescope and provider == "telescope" then
    vim.notify("Rails: telescope.nvim not found, falling back to vim.ui.select", vim.log.levels.WARN)
  end
  return has_telescope
end

---@param root string
---@param parsed RailsToolsRoute[]
---@param picker_opts table
local function pick_with_telescope(root, parsed, picker_opts)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local telescope_config = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers
    .new(picker_opts, {
      prompt_title = PICKER_TITLE,
      finder = finders.new_table({
        results = parsed,
        entry_maker = function(route)
          local text = format_route(route)
          return { value = route, display = text, ordinal = text }
        end,
      }),
      sorter = telescope_config.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection then
            open_route(root, selection.value)
          end
        end)
        return true
      end,
    })
    :find()
end

---@param root string
---@param parsed RailsToolsRoute[]
local function pick_with_select(root, parsed)
  vim.ui.select(parsed, { prompt = PICKER_TITLE, format_item = format_route }, function(choice)
    if choice then
      open_route(root, choice)
    end
  end)
end

---@param root string
---@param parsed RailsToolsRoute[]
---@param opts RailsToolsRoutesShowOpts
local function pick(root, parsed, opts)
  if use_telescope(opts.provider or config.get().finder.provider or "auto") then
    pick_with_telescope(root, parsed, opts.picker_opts or {})
  else
    pick_with_select(root, parsed)
  end
end

---@param stderr string[]
---@return string[]
local function error_lines(stderr)
  local lines = {}
  for _, line in ipairs(stderr) do
    if vim.trim(line) ~= "" and #lines < MAX_ERROR_LINES then
      table.insert(lines, line)
    end
  end
  return lines
end

---@param root string
---@param exit_code integer
---@param stdout string[]
---@param stderr string[]
---@param opts RailsToolsRoutesShowOpts
local function on_command_finished(root, exit_code, stdout, stderr, opts)
  if exit_code ~= 0 then
    local message = ("Rails: routes command failed (exit %d)"):format(exit_code)
    local details = error_lines(stderr)
    if #details > 0 then
      message = message .. "\n" .. table.concat(details, "\n")
    end
    vim.notify(message, vim.log.levels.ERROR)
    return
  end

  local parsed = M.parse(table.concat(stdout, "\n"))
  if #parsed == 0 then
    vim.notify("Rails: no routes found", vim.log.levels.INFO)
    return
  end

  routes_cache:set(root, parsed)
  pick(root, parsed, opts)
end

---@param root string
local function stop_job(root)
  local job_id = running_jobs[root]
  if job_id then
    running_jobs[root] = nil
    vim.fn.jobstop(job_id)
  end
end

---@param root string
---@param opts RailsToolsRoutesShowOpts
local function load_routes(root, opts)
  local routes_config = config.get().routes
  local command = vim.trim(routes_config.command .. " " .. (routes_config.args or ""))
  local stdout = {}
  local stderr = {}
  local job_id

  vim.notify("Rails: loading routes...", vim.log.levels.INFO)
  local started, job_or_error = pcall(vim.fn.jobstart, command, {
    cwd = root,
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      stdout = data
    end,
    on_stderr = function(_, data)
      stderr = data
    end,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        if running_jobs[root] ~= job_id then
          return
        end
        running_jobs[root] = nil
        on_command_finished(root, exit_code, stdout, stderr, opts)
      end)
    end,
  })

  if not started or job_or_error <= 0 then
    vim.notify(("Rails: could not run '%s'"):format(command), vim.log.levels.ERROR)
    return
  end
  job_id = job_or_error
  running_jobs[root] = job_id
end

---Show the routes of the current Rails project in a picker and jump to the chosen action.
---Uses the cache when it is younger than `routes.cache_ttl`, otherwise runs the routes command async.
---@param opts? RailsToolsRoutesShowOpts
function M.show(opts)
  opts = opts or {}
  local root = rails_root_or_warn()
  if not root then
    return
  end

  routes_cache.ttl = config.get().routes.cache_ttl
  local cached = routes_cache:peek(root)
  if cached then
    pick(root, cached, opts)
    return
  end

  if running_jobs[root] then
    vim.notify("Rails: routes are still loading (:Rails routes! to restart)", vim.log.levels.INFO)
    return
  end

  load_routes(root, opts)
end

---Clear the cached routes, stop a running routes command and load the routes again
---@param opts? RailsToolsRoutesShowOpts
function M.refresh(opts)
  opts = opts or {}
  local root = rails_root_or_warn()
  if not root then
    return
  end

  stop_job(root)
  routes_cache:invalidate(root)
  load_routes(root, opts)
end

return M

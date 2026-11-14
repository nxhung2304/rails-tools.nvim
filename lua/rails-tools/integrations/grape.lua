local cache = require("rails-tools.cache")
local config = require("rails-tools.config")
local rails = require("rails-tools.detectors.rails")

local M = {}

local PICKER_TITLE = "Grape endpoints"
local MAX_ERROR_LINES = 20
local VERB_COLUMN_WIDTH = 7
local ROUTE_LINE_PREFIX = "RAILS_TOOLS_GRAPE_ROUTE "

local LIST_ROUTES_SCRIPT = [[
require "json"
if defined?(Grape::API)
  Rails.application.reload_routes_unless_loaded if Rails.application.respond_to?(:reload_routes_unless_loaded)
  Rails.application.routes.routes.each do |rails_route|
    api = rails_route.app
    api = api.app if api.is_a?(ActionDispatch::Routing::Mapper::Constraints)
    next unless api.is_a?(Class) && api < Grape::API

    mount_path = rails_route.path.spec.to_s.sub(%r{/\z}, "")
    api.routes.each do |route|
      file, line = (route.app.source.source_location rescue nil)
      path = route.origin.to_s
      path = path.sub(":version", route.version) if route.version.is_a?(String)
      puts "RAILS_TOOLS_GRAPE_ROUTE " + JSON.generate(
        verb: route.request_method.to_s,
        path: mount_path + path,
        description: route.description.to_s,
        api: api.name.to_s,
        file: file,
        line: line
      )
    end
  end
end
]]

---@class RailsToolsGrapeRoute
---@field verb string HTTP verb
---@field path string full path, including the Rails mount path, prefix and version
---@field description string text from `desc`, "" when the endpoint has none
---@field api string name of the Grape API class mounted in the Rails routes
---@field file? string file that defines the endpoint
---@field line? integer line of the endpoint in `file`

---@class RailsToolsGrapeShowOpts
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

---@param line string
---@return RailsToolsGrapeRoute|nil
local function parse_line(line)
  if line:sub(1, #ROUTE_LINE_PREFIX) ~= ROUTE_LINE_PREFIX then
    return nil
  end

  local decoded, route = pcall(vim.json.decode, line:sub(#ROUTE_LINE_PREFIX + 1))
  if not decoded or type(route) ~= "table" or type(route.verb) ~= "string" or type(route.path) ~= "string" then
    return nil
  end

  return {
    verb = route.verb,
    path = route.path,
    description = type(route.description) == "string" and route.description or "",
    api = type(route.api) == "string" and route.api or "",
    file = type(route.file) == "string" and route.file or nil,
    line = type(route.line) == "number" and route.line or nil,
  }
end

---Parse the routes printed by the Grape route listing script, ignoring any other output
---@param output string
---@return RailsToolsGrapeRoute[]
function M.parse(output)
  local parsed = {}
  for _, line in ipairs(vim.split(output, "\n", { plain = true })) do
    local route = parse_line(line)
    if route then
      table.insert(parsed, route)
    end
  end
  return parsed
end

---@param root string
---@param file string
---@return string
local function absolute_path(root, file)
  if file:sub(1, 1) == "/" then
    return file
  end
  return root .. "/" .. file
end

---@param root string
---@param route RailsToolsGrapeRoute
local function open_route(root, route)
  if not route.file then
    vim.notify(("Rails: no source location for %s %s"):format(route.verb, route.path), vim.log.levels.INFO)
    return
  end

  local file_path = absolute_path(root, route.file)
  if vim.fn.filereadable(file_path) == 0 then
    vim.notify(("Rails: %s not found"):format(route.file), vim.log.levels.INFO)
    return
  end

  local opened, err = pcall(vim.cmd.edit, vim.fn.fnameescape(file_path))
  if not opened then
    vim.notify(("Rails: %s"):format(err), vim.log.levels.ERROR)
    return
  end

  local last_line = vim.api.nvim_buf_line_count(0)
  vim.api.nvim_win_set_cursor(0, { math.min(route.line or 1, last_line), 0 })
end

---Open the file of a Grape endpoint at the line that defines it
---@param route RailsToolsGrapeRoute
function M.goto_endpoint(route)
  local root = rails_root_or_warn()
  if not root then
    return
  end

  open_route(root, route)
end

---@param route RailsToolsGrapeRoute
---@return string
local function format_route(route)
  local padded_verb = ("%-" .. VERB_COLUMN_WIDTH .. "s"):format(route.verb)
  local text = ("%s %s"):format(padded_verb, route.path)
  if route.description ~= "" then
    text = ("%s  (%s)"):format(text, route.description)
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
---@param parsed RailsToolsGrapeRoute[]
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
---@param parsed RailsToolsGrapeRoute[]
local function pick_with_select(root, parsed)
  vim.ui.select(parsed, { prompt = PICKER_TITLE, format_item = format_route }, function(choice)
    if choice then
      open_route(root, choice)
    end
  end)
end

---@param root string
---@param parsed RailsToolsGrapeRoute[]
---@param opts RailsToolsGrapeShowOpts
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
---@param opts RailsToolsGrapeShowOpts
local function on_command_finished(root, exit_code, stdout, stderr, opts)
  if exit_code ~= 0 then
    local message = ("Rails: Grape routes command failed (exit %d)"):format(exit_code)
    local details = error_lines(stderr)
    if #details > 0 then
      message = message .. "\n" .. table.concat(details, "\n")
    end
    vim.notify(message, vim.log.levels.ERROR)
    return
  end

  local parsed = M.parse(table.concat(stdout, "\n"))
  if #parsed == 0 then
    vim.notify("Rails: no Grape routes found (is the Grape API mounted in config/routes.rb?)", vim.log.levels.INFO)
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
---@param opts RailsToolsGrapeShowOpts
local function load_routes(root, opts)
  local command = config.get().runner.command .. " " .. vim.fn.shellescape(LIST_ROUTES_SCRIPT)
  local stdout = {}
  local stderr = {}
  local job_id

  vim.notify("Rails: loading Grape routes...", vim.log.levels.INFO)
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
    vim.notify(("Rails: could not run '%s'"):format(config.get().runner.command), vim.log.levels.ERROR)
    return
  end
  job_id = job_or_error
  running_jobs[root] = job_id
end

---Show the Grape endpoints mounted in the Rails routes in a picker and jump to the chosen one.
---Uses the cache when it is younger than `routes.cache_ttl`, otherwise runs `runner.command` async.
---@param opts? RailsToolsGrapeShowOpts
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
    vim.notify("Rails: Grape routes are still loading (:Rails grape routes! to restart)", vim.log.levels.INFO)
    return
  end

  load_routes(root, opts)
end

---Clear the cached Grape routes, stop a running listing and load them again
---@param opts? RailsToolsGrapeShowOpts
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

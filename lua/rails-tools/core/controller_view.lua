local rails = require("rails-tools.detectors.rails")
local rails_paths = require("rails-tools.core.rails_paths")
local model_context = require("rails-tools.core.model_context")
local annotate = require("rails-tools.core.annotate")
local schema = require("rails-tools.core.schema")

local M = {}

local CONTROLLERS_DIR = "app/controllers/"
local MAILERS_DIR = "app/mailers/"
local HELPERS_DIR = "app/helpers/"
local LAYOUTS_FOLDER = "layouts"
local APPLICATION_LAYOUT = "application"
local SCHEMA_FILE = "db/schema.rb"
local MIGRATIONS_GLOB = "db/migrate/*.rb"
local SELECT_PROMPT = "Rails related"

---@type string[]
M.TYPES = { "view", "controller", "helper", "model", "layout", "schema", "fixture", "migration" }

local TYPES_BY_KIND = {
  controller = { "view", "helper", "model", "layout" },
  view = { "controller", "helper", "model", "layout" },
  model = { "controller", "schema", "fixture", "migration" },
  migration = { "model" },
  helper = { "controller" },
}

local HIDDEN_SECTION_PATTERNS = { "^%s*private%s*$", "^%s*protected%s*$" }
local HIDDEN_DEF_PATTERNS = { "^%s*private%s+def%s", "^%s*protected%s+def%s" }
local DEF_PATTERN = "^%s*def%s+([%w_]+[?!]?)%s*([%.]?)"

---@class RailsFileKind
---@field kind "controller"|"view"|"model"|"migration"|"helper"
---@field path? string controller, model or helper path, e.g. `admin/users`
---@field folder? string view folder under app/views
---@field action? string view file name before the first `.`
---@field is_partial? boolean
---@field is_layout? boolean

---@class RelatedEntry
---@field type string
---@field path string relative to the Rails root
---@field lnum? integer

---@class RelatedMissing
---@field message string
---@field create_path? string view to offer to create

---@class RelatedContext
---@field root string
---@field relative_file string
---@field lines string[] current buffer lines
---@field cursor_lnum integer

---What kind of Rails file `relative_file` is, nil when it has no related files.
---@param relative_file string path relative to the Rails root
---@return RailsFileKind|nil
function M.kind_of(relative_file)
  local controller_path = relative_file:match("^app/controllers/(.+)_controller%.rb$")
  if controller_path then
    return { kind = "controller", path = controller_path }
  end
  local folder, file_name = relative_file:match("^app/views/(.+)/([^/]+)$")
  local action = file_name and file_name:match("^([^.]+)")
  if action then
    local is_layout_folder = folder == LAYOUTS_FOLDER
    local is_inside_layouts = folder:sub(1, #LAYOUTS_FOLDER + 1) == LAYOUTS_FOLDER .. "/"
    return {
      kind = "view",
      folder = folder,
      action = action,
      is_partial = action:sub(1, 1) == "_",
      is_layout = is_layout_folder or is_inside_layouts,
    }
  end
  local model_path = relative_file:match("^app/models/(.+)%.rb$")
  if model_path and not model_path:match("^concerns/") then
    return { kind = "model", path = model_path }
  end
  if relative_file:match("^db/migrate/.+%.rb$") then
    return { kind = "migration" }
  end
  local helper_path = relative_file:match("^app/helpers/(.+)_helper%.rb$")
  if helper_path then
    return { kind = "helper", path = helper_path }
  end
  return nil
end

---@param line string
---@param patterns string[]
---@return boolean
local function matches_any(line, patterns)
  for _, pattern in ipairs(patterns) do
    if line:match(pattern) then
      return true
    end
  end
  return false
end

---Public action whose `def` is the nearest one at or above `lnum`.
---@param lines string[]
---@param lnum integer 1-indexed cursor line
---@return string|nil nil when there is no def, it is a class method, or it is private/protected
function M.action_at(lines, lnum)
  local action
  local is_hidden_section = false
  local is_hidden_action = false
  for index = 1, math.min(lnum, #lines) do
    local line = lines[index]
    if matches_any(line, HIDDEN_SECTION_PATTERNS) then
      is_hidden_section = true
    end
    local name, receiver_dot = line:match(DEF_PATTERN)
    local is_hidden_def = matches_any(line, HIDDEN_DEF_PATTERNS)
    if is_hidden_def then
      name = line:match("def%s+([%w_]+[?!]?)")
    end
    if name then
      action = receiver_dot ~= "." and name or nil
      is_hidden_action = is_hidden_section or is_hidden_def
    end
  end
  if is_hidden_action then
    return nil
  end
  return action
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
---@param relative string
---@return string[]
local function read_lines(root, relative)
  local readable, lines = pcall(vim.fn.readfile, root .. "/" .. relative)
  return readable and lines or {}
end

---@param message string
---@param create_path? string
---@return RelatedEntry[], RelatedMissing
local function not_found(message, create_path)
  return {}, { message = "Rails: " .. message, create_path = create_path }
end

---@param related_type string
---@param paths string[]
---@return RelatedEntry[]
local function entries_of(related_type, paths)
  return vim.tbl_map(function(path)
    return { type = related_type, path = path }
  end, paths)
end

---@param root string
---@param folder string
---@return string[]
local function files_in_view_folder(root, folder)
  local files = vim.tbl_filter(function(path)
    return vim.fn.filereadable(path) == 1
  end, vim.fn.glob(root .. "/" .. rails_paths.VIEWS_DIR .. folder .. "/*", false, true))
  table.sort(files)
  return vim.tbl_map(function(path)
    return rails_paths.relative_path(root, path)
  end, files)
end

---@param folder string
---@param base string
---@return string
local function new_view_path(folder, base)
  return ("%s%s/%s.%s.%s"):format(
    rails_paths.VIEWS_DIR,
    folder,
    base,
    rails_paths.DEFAULT_FORMAT,
    rails_paths.default_engine()
  )
end

---@param ctx RelatedContext
---@param file_kind RailsFileKind
---@return RelatedEntry[], RelatedMissing|nil
local function find_views(ctx, file_kind)
  local action = M.action_at(ctx.lines, ctx.cursor_lnum)
  if not action then
    local all_views = files_in_view_folder(ctx.root, file_kind.path)
    if #all_views == 0 then
      return not_found(("no views in %s%s/"):format(rails_paths.VIEWS_DIR, file_kind.path))
    end
    return entries_of("view", all_views)
  end
  local views = rails_paths.view_candidates(ctx.root, file_kind.path, action, rails_paths.DEFAULT_FORMAT)
  if #views == 0 then
    local new_view = new_view_path(file_kind.path, action)
    return not_found("view not found: " .. new_view, new_view)
  end
  return entries_of("view", views)
end

---@param ctx RelatedContext
---@param file_kind RailsFileKind
---@return RelatedEntry[], RelatedMissing|nil
local function find_controller_of_view(ctx, file_kind)
  if file_kind.is_layout then
    return not_found("no controller for a layout view")
  end
  local candidates = {
    ("%s%s_controller.rb"):format(CONTROLLERS_DIR, file_kind.folder),
    ("%s%s.rb"):format(MAILERS_DIR, file_kind.folder),
  }
  for _, path in ipairs(candidates) do
    if rails_paths.exists(ctx.root, path) then
      local action_line
      if not file_kind.is_partial then
        action_line = def_line(read_lines(ctx.root, path), file_kind.action)
      end
      return { { type = "controller", path = path, lnum = action_line or 1 } }
    end
  end
  return not_found("controller not found: " .. candidates[1])
end

---@param ctx RelatedContext
---@param file_kind RailsFileKind
---@return RelatedEntry[], RelatedMissing|nil
local function find_controller(ctx, file_kind)
  if file_kind.kind == "view" then
    return find_controller_of_view(ctx, file_kind)
  end
  local controller_path = file_kind.path
  if file_kind.kind == "model" then
    controller_path = model_context.pluralize(file_kind.path)
  end
  local path = ("%s%s_controller.rb"):format(CONTROLLERS_DIR, controller_path)
  if not rails_paths.exists(ctx.root, path) then
    return not_found("controller not found: " .. path)
  end
  return { { type = "controller", path = path } }
end

---@param file_kind RailsFileKind
---@return string
local function resource_path(file_kind)
  return file_kind.path or file_kind.folder
end

---@param ctx RelatedContext
---@param file_kind RailsFileKind
---@return RelatedEntry[], RelatedMissing|nil
local function find_helper(ctx, file_kind)
  local path = ("%s%s_helper.rb"):format(HELPERS_DIR, resource_path(file_kind))
  if not rails_paths.exists(ctx.root, path) then
    return not_found("helper not found: " .. path)
  end
  return { { type = "helper", path = path } }
end

---@param ctx RelatedContext
---@return RelatedEntry[], RelatedMissing|nil
local function find_model_of_migration(ctx)
  for _, line in ipairs(ctx.lines) do
    for _, argument in ipairs(rails_paths.migration_arguments(line)) do
      if argument.kind == "table" then
        local path = rails_paths.model_file_for_table(ctx.root, argument.name)
        if not rails_paths.exists(ctx.root, path) then
          return not_found("model not found: " .. path)
        end
        return { { type = "model", path = path } }
      end
    end
  end
  return not_found("no table in this migration")
end

---@param ctx RelatedContext
---@param file_kind RailsFileKind
---@return RelatedEntry[], RelatedMissing|nil
local function find_model(ctx, file_kind)
  if file_kind.kind == "migration" then
    return find_model_of_migration(ctx)
  end
  if file_kind.is_layout then
    return not_found("no model for a layout view")
  end
  local namespace, resource = resource_path(file_kind):match("^(.-)/?([^/]+)$")
  local singular = model_context.singularize(resource)
  local candidates = { rails_paths.MODELS_DIR .. singular .. ".rb" }
  if namespace ~= "" then
    table.insert(candidates, 1, ("%s%s/%s.rb"):format(rails_paths.MODELS_DIR, namespace, singular))
  end
  for _, path in ipairs(candidates) do
    if rails_paths.exists(ctx.root, path) then
      return { { type = "model", path = path } }
    end
  end
  return not_found("model not found: " .. candidates[1])
end

---@param ctx RelatedContext
---@param file_kind RailsFileKind
---@return RelatedEntry[], RelatedMissing|nil
local function find_layout(ctx, file_kind)
  local format = rails_paths.DEFAULT_FORMAT
  local layouts = rails_paths.view_candidates(ctx.root, LAYOUTS_FOLDER, resource_path(file_kind), format)
  if #layouts == 0 then
    layouts = rails_paths.view_candidates(ctx.root, LAYOUTS_FOLDER, APPLICATION_LAYOUT, format)
  end
  if #layouts == 0 then
    return not_found("layout not found: " .. new_view_path(LAYOUTS_FOLDER, APPLICATION_LAYOUT))
  end
  return entries_of("layout", layouts)
end

---@param ctx RelatedContext
---@param file_kind RailsFileKind
---@return string
local function table_of_model(ctx, file_kind)
  local relative_model = rails_paths.MODELS_DIR .. file_kind.path .. ".rb"
  local annotated_table = annotate.parse(read_lines(ctx.root, relative_model)).table_name
  return annotated_table or model_context.pluralize(vim.fn.fnamemodify(file_kind.path, ":t"))
end

---@param ctx RelatedContext
---@param file_kind RailsFileKind
---@return RelatedEntry[], RelatedMissing|nil
local function find_schema(ctx, file_kind)
  if not rails_paths.exists(ctx.root, SCHEMA_FILE) then
    return not_found("schema not found: " .. SCHEMA_FILE)
  end
  local table_name = table_of_model(ctx, file_kind)
  local schema_table = schema.parse(read_lines(ctx.root, SCHEMA_FILE))[table_name]
  if not schema_table then
    return not_found(("table %s not found in %s"):format(table_name, SCHEMA_FILE))
  end
  return { { type = "schema", path = SCHEMA_FILE, lnum = schema_table.lnum } }
end

---@param ctx RelatedContext
---@param file_kind RailsFileKind
---@return RelatedEntry[], RelatedMissing|nil
local function find_fixture(ctx, file_kind)
  local table_name = table_of_model(ctx, file_kind)
  local path = rails_paths.fixture_file(ctx.root, table_name)
  if not path then
    return not_found(("fixture not found: %s/%s.yml"):format(rails_paths.FIXTURE_DIRS[1], table_name))
  end
  return { { type = "fixture", path = path } }
end

---@param lines string[]
---@param table_name string
---@return boolean
local function touches_table(lines, table_name)
  for _, line in ipairs(lines) do
    for _, argument in ipairs(rails_paths.migration_arguments(line)) do
      if argument.kind == "table" and argument.name == table_name then
        return true
      end
    end
  end
  return false
end

---@param ctx RelatedContext
---@param file_kind RailsFileKind
---@return RelatedEntry[], RelatedMissing|nil
local function find_migrations(ctx, file_kind)
  local table_name = table_of_model(ctx, file_kind)
  local migrations = vim.fn.globpath(ctx.root, MIGRATIONS_GLOB, false, true)
  table.sort(migrations, function(left, right)
    return left > right
  end)
  local paths = {}
  for _, migration in ipairs(migrations) do
    local relative = rails_paths.relative_path(ctx.root, migration)
    if touches_table(read_lines(ctx.root, relative), table_name) then
      table.insert(paths, relative)
    end
  end
  if #paths == 0 then
    return not_found("no migration for table " .. table_name)
  end
  return entries_of("migration", paths)
end

local FINDERS = {
  view = find_views,
  controller = find_controller,
  helper = find_helper,
  model = find_model,
  layout = find_layout,
  schema = find_schema,
  fixture = find_fixture,
  migration = find_migrations,
}

---Related files of one type for the current file.
---@param ctx RelatedContext
---@param related_type string one of `M.TYPES`
---@return RelatedEntry[] entries, empty when nothing is found
---@return RelatedMissing|nil missing why nothing was found
function M.find(ctx, related_type)
  local file_kind = M.kind_of(ctx.relative_file)
  if not file_kind or not vim.tbl_contains(TYPES_BY_KIND[file_kind.kind], related_type) then
    return not_found(("no %s for this file"):format(related_type))
  end
  return FINDERS[related_type](ctx, file_kind)
end

---Every related file that exists for the current file, in `M.TYPES` order.
---@param ctx RelatedContext
---@return RelatedEntry[]
function M.related(ctx)
  local file_kind = M.kind_of(ctx.relative_file)
  if not file_kind then
    return {}
  end
  local entries = {}
  for _, related_type in ipairs(M.TYPES) do
    if vim.tbl_contains(TYPES_BY_KIND[file_kind.kind], related_type) then
      vim.list_extend(entries, (M.find(ctx, related_type)))
    end
  end
  return entries
end

---@return RelatedContext|nil
local function current_context()
  local file = vim.api.nvim_buf_get_name(0)
  local root
  if file ~= "" then
    root = rails.root(vim.fn.fnamemodify(file, ":p:h"))
  end
  if not root then
    vim.notify("Rails: not a Rails project", vim.log.levels.WARN)
    return nil
  end
  return {
    root = root,
    relative_file = rails_paths.relative_path(root, file),
    lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
    cursor_lnum = vim.api.nvim_win_get_cursor(0)[1],
  }
end

---@param root string
---@param entry RelatedEntry
local function open_entry(root, entry)
  vim.cmd.edit(vim.fn.fnameescape(root .. "/" .. entry.path))
  if entry.lnum then
    vim.api.nvim_win_set_cursor(0, { entry.lnum, 0 })
  end
end

---@param root string
---@param entries RelatedEntry[]
---@param with_type boolean label entries as `<type>: <path>`
local function open_entries(root, entries, with_type)
  if #entries == 1 then
    open_entry(root, entries[1])
    return
  end
  vim.ui.select(entries, {
    prompt = SELECT_PROMPT,
    format_item = function(entry)
      return with_type and ("%s: %s"):format(entry.type, entry.path) or entry.path
    end,
  }, function(choice)
    if choice then
      open_entry(root, choice)
    end
  end)
end

---@param root string
---@param relative string
local function create_view(root, relative)
  local answer = vim.fn.input(("Create %s ? (y/N): "):format(relative))
  if not answer:lower():match("^y") then
    return
  end
  local absolute = root .. "/" .. relative
  vim.fn.mkdir(vim.fn.fnamemodify(absolute, ":h"), "p")
  vim.fn.writefile({}, absolute)
  vim.cmd.edit(vim.fn.fnameescape(absolute))
end

---@param ctx RelatedContext
---@param related_type string
local function open_found(ctx, related_type)
  local entries, missing = M.find(ctx, related_type)
  if #entries > 0 then
    open_entries(ctx.root, entries, false)
  elseif missing and missing.create_path then
    create_view(ctx.root, missing.create_path)
  elseif missing then
    vim.notify(missing.message, vim.log.levels.INFO)
  end
end

---Open the related file of `related_type` for the current buffer; several matches are picked from a list.
---@param related_type string one of `M.TYPES`
function M.open_type(related_type)
  if not vim.tbl_contains(M.TYPES, related_type) then
    vim.notify(("Rails: usage: :Rails related [%s]"):format(table.concat(M.TYPES, "|")), vim.log.levels.ERROR)
    return
  end
  local ctx = current_context()
  if ctx then
    open_found(ctx, related_type)
  end
end

---Open the view of the controller action at the cursor, or pick one of the controller's views.
function M.to_view()
  M.open_type("view")
end

---Open the controller (or mailer) of the current view at its action.
function M.from_view()
  M.open_type("controller")
end

---Switch between a controller action and its view.
function M.toggle()
  local ctx = current_context()
  if not ctx then
    return
  end
  local file_kind = M.kind_of(ctx.relative_file)
  if file_kind and file_kind.kind == "controller" then
    open_found(ctx, "view")
  elseif file_kind and file_kind.kind == "view" then
    open_found(ctx, "controller")
  else
    vim.notify("Rails: not a controller or view", vim.log.levels.INFO)
  end
end

---Pick one of the existing related files of the current buffer.
function M.related_menu()
  local ctx = current_context()
  if not ctx then
    return
  end
  local entries = M.related(ctx)
  if #entries == 0 then
    vim.notify("Rails: no related files for this file", vim.log.levels.INFO)
    return
  end
  open_entries(ctx.root, entries, true)
end

return M

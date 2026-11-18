local rails_paths = require("rails-tools.core.rails_paths")
local rails_file_kind = require("rails-tools.core.rails_file_kind")
local model_context = require("rails-tools.core.model_context")
local annotate = require("rails-tools.core.annotate")
local schema = require("rails-tools.core.schema")

local M = {}

local CONTROLLERS_DIR = "app/controllers/"
local MAILERS_DIR = "app/mailers/"
local HELPERS_DIR = "app/helpers/"
local APPLICATION_LAYOUT = "application"
local SCHEMA_FILE = "db/schema.rb"
local MIGRATIONS_GLOB = "db/migrate/*.rb"

---@type string[]
M.TYPES = { "view", "controller", "helper", "model", "layout", "schema", "fixture", "migration" }

local TYPES_BY_KIND = {
  controller = { "view", "helper", "model", "layout" },
  view = { "controller", "helper", "model", "layout" },
  model = { "controller", "schema", "fixture", "migration" },
  migration = { "model" },
  helper = { "controller" },
}

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
  local action = rails_file_kind.action_at(ctx.lines, ctx.cursor_lnum)
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
  local layouts_folder = rails_file_kind.LAYOUTS_FOLDER
  local layouts = rails_paths.view_candidates(ctx.root, layouts_folder, resource_path(file_kind), format)
  if #layouts == 0 then
    layouts = rails_paths.view_candidates(ctx.root, layouts_folder, APPLICATION_LAYOUT, format)
  end
  if #layouts == 0 then
    return not_found("layout not found: " .. new_view_path(layouts_folder, APPLICATION_LAYOUT))
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
  local file_kind = rails_file_kind.kind_of(ctx.relative_file)
  if not file_kind or not vim.tbl_contains(TYPES_BY_KIND[file_kind.kind], related_type) then
    return not_found(("no %s for this file"):format(related_type))
  end
  return FINDERS[related_type](ctx, file_kind)
end

---Every related file that exists for the current file, in `M.TYPES` order.
---@param ctx RelatedContext
---@return RelatedEntry[]
function M.related(ctx)
  local file_kind = rails_file_kind.kind_of(ctx.relative_file)
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

return M

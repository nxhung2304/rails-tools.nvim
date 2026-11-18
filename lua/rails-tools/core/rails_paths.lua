local config = require("rails-tools.config")
local annotate = require("rails-tools.core.annotate")
local model_context = require("rails-tools.core.model_context")

local M = {}

M.VIEWS_DIR = "app/views/"
M.MODELS_DIR = "app/models/"
M.FIXTURE_DIRS = { "test/fixtures", "spec/fixtures" }
M.DEFAULT_FORMAT = "html"
local DEFAULT_ENGINE = "erb"
local MIN_PARTS_WITH_FORMAT = 3

local TABLE_ARGUMENTS = {
  create_table = { 1 },
  change_table = { 1 },
  drop_table = { 1 },
  create_join_table = { 1, 2 },
  rename_table = { 1, 2 },
  add_column = { 1 },
  remove_column = { 1 },
  change_column = { 1 },
  change_column_default = { 1 },
  change_column_null = { 1 },
  rename_column = { 1 },
  add_index = { 1 },
  remove_index = { 1 },
  add_reference = { 1 },
  remove_reference = { 1 },
  add_belongs_to = { 1 },
  remove_belongs_to = { 1 },
  add_timestamps = { 1 },
  remove_timestamps = { 1 },
  add_foreign_key = { 1, 2 },
  remove_foreign_key = { 1, 2 },
}

local REFERENCE_ARGUMENTS = {
  add_reference = { 2 },
  remove_reference = { 2 },
  add_belongs_to = { 2 },
  remove_belongs_to = { 2 },
}

local BLOCK_REFERENCE_METHODS = { references = true, belongs_to = true }

---@class RailsMigrationArgument
---@field name string symbol or string argument without `:` or quotes
---@field start integer 1-indexed byte where the argument starts on the line
---@field finish integer 1-indexed byte where the argument ends on the line
---@field kind "table"|"reference"|nil what the argument names, nil for anything else (e.g. a column)

---Path of `file` relative to `root`, or `file` unchanged when it is outside `root`.
---@param root string
---@param file string
---@return string
function M.relative_path(root, file)
  local prefix = root .. "/"
  if file:sub(1, #prefix) == prefix then
    return file:sub(#prefix + 1)
  end
  return file
end

---@param root string
---@param relative string
---@return boolean
function M.exists(root, relative)
  return vim.fn.filereadable(root .. "/" .. relative) == 1
end

---Format part of a view file name (`show.html.erb` -> `html`), `html` when there is none.
---@param relative_file string
---@return string
function M.format_of(relative_file)
  local parts = vim.split(vim.fn.fnamemodify(relative_file, ":t"), ".", { plain = true })
  if #parts >= MIN_PARTS_WITH_FORMAT then
    return parts[#parts - 1]
  end
  return M.DEFAULT_FORMAT
end

---Engine used for a new view: `view.engine` when not "auto", else the first of `view.priority`.
---@return string
function M.default_engine()
  local configured = config.get().view.engine
  if configured and configured ~= "auto" then
    return configured
  end
  return (config.get().view.priority or {})[1] or DEFAULT_ENGINE
end

---@param engine string
---@return integer
local function engine_rank(engine)
  for index, preferred in ipairs(config.get().view.priority or {}) do
    if preferred == engine then
      return index
    end
  end
  return math.huge
end

---@param engine string
---@return boolean
local function is_allowed_engine(engine)
  local configured = config.get().view.engine
  return configured == nil or configured == "auto" or configured == engine
end

---@param root string
---@param folder string
---@param base string
---@return {path: string, format: string|nil, engine: string}[]
local function view_files(root, folder, base)
  local view_prefix = M.VIEWS_DIR .. folder .. "/" .. base .. "."
  local files = {}
  for _, path in ipairs(vim.fn.glob(root .. "/" .. view_prefix .. "*", false, true)) do
    local relative = M.relative_path(root, path)
    local extensions = relative:sub(#view_prefix + 1)
    local format, engine = extensions:match("^([^.]+)%.([^.]+)$")
    if not format then
      engine = extensions:match("^([^.]+)$")
    end
    if engine and is_allowed_engine(engine) then
      table.insert(files, { path = relative, format = format, engine = engine })
    end
  end
  return files
end

---@param files {path: string, format: string|nil, engine: string}[]
---@param keep fun(format: string|nil): boolean
---@return string[]
local function paths_by_engine(files, keep)
  local kept = vim.tbl_filter(function(file)
    return keep(file.format)
  end, files)
  table.sort(kept, function(left, right)
    local left_rank, right_rank = engine_rank(left.engine), engine_rank(right.engine)
    if left_rank ~= right_rank then
      return left_rank < right_rank
    end
    return left.path < right.path
  end)
  return vim.tbl_map(function(file)
    return file.path
  end, kept)
end

---Existing views `app/views/<folder>/<base>.*` for `format`, ordered by `view.priority`.
---Falls back to html and format-less views when none has `format`.
---@param root string
---@param folder string folder under app/views, e.g. `admin/users`
---@param base string file name before the first `.`, e.g. `show` or `_form`
---@param format string e.g. `html`, `json`
---@return string[] paths relative to `root`
function M.view_candidates(root, folder, base, format)
  local files = view_files(root, folder, base)
  local candidates = paths_by_engine(files, function(file_format)
    return file_format == format
  end)
  if #candidates == 0 then
    candidates = paths_by_engine(files, function(file_format)
      return file_format == nil or file_format == M.DEFAULT_FORMAT
    end)
  end
  return candidates
end

---Model file of a table: the model whose annotate block says `# Table name: <table>`,
---else `app/models/<singular>.rb` (which may not exist).
---@param root string
---@param table_name string
---@return string path relative to `root`
function M.model_file_for_table(root, table_name)
  for _, model_file in ipairs(vim.fn.globpath(root, M.MODELS_DIR .. "**/*.rb", false, true)) do
    local readable, lines = pcall(vim.fn.readfile, model_file)
    if readable and annotate.parse(lines).table_name == table_name then
      return M.relative_path(root, model_file)
    end
  end
  return M.MODELS_DIR .. model_context.singularize(table_name) .. ".rb"
end

---Fixture file of `name` in test/fixtures, then spec/fixtures.
---@param root string
---@param name string
---@return string|nil path relative to `root`, nil when there is none
function M.fixture_file(root, name)
  for _, folder in ipairs(M.FIXTURE_DIRS) do
    local relative = ("%s/%s.yml"):format(folder, name)
    if M.exists(root, relative) then
      return relative
    end
  end
  return nil
end

---@param line string
---@return string|nil method, string|nil receiver, integer|nil arguments_start
local function migration_call(line)
  local receiver_start, receiver, method, arguments_start = line:match("^%s*()([%a_][%w_]*)%.([%a_][%w_]*)%s*%(?%s*()")
  if receiver_start then
    return method, receiver, arguments_start
  end
  method, arguments_start = line:match("^%s*([%a_][%w_]*)%s*%(?%s*()")
  return method, nil, arguments_start
end

---@param line string
---@param arguments_start integer
---@return {name: string, start: integer, finish: integer}[]
local function positional_arguments(line, arguments_start)
  local arguments = {}
  local position = arguments_start
  while true do
    local start, finish, name = line:find("^:([%w_]+)", position)
    if not start then
      start, finish, name = line:find("^[\"']([%w_]+)[\"']", position)
    end
    if not start then
      return arguments
    end
    table.insert(arguments, { name = name, start = start, finish = finish })
    local _, separator_finish = line:find("^%s*,%s*", finish + 1)
    if not separator_finish then
      return arguments
    end
    position = separator_finish + 1
  end
end

---@param method string
---@param receiver string|nil
---@param argument_index integer
---@return "table"|"reference"|nil
local function migration_argument_kind(method, receiver, argument_index)
  if receiver then
    return BLOCK_REFERENCE_METHODS[method] and "reference" or nil
  end
  if vim.tbl_contains(REFERENCE_ARGUMENTS[method] or {}, argument_index) then
    return "reference"
  end
  if vim.tbl_contains(TABLE_ARGUMENTS[method] or {}, argument_index) then
    return "table"
  end
  return nil
end

---Leading symbol/string arguments of a migration line, each with what it names.
---@param line string
---@return RailsMigrationArgument[]
function M.migration_arguments(line)
  local method, receiver, arguments_start = migration_call(line)
  if not method then
    return {}
  end
  local arguments = positional_arguments(line, arguments_start)
  for index, argument in ipairs(arguments) do
    argument.kind = migration_argument_kind(method, receiver, index)
  end
  return arguments
end

return M

local config = require("rails-tools.config")
local rails = require("rails-tools.detectors.rails")
local annotate = require("rails-tools.core.annotate")
local model_context = require("rails-tools.core.model_context")
local context = require("rails-tools.integrations.context")
local routes = require("rails-tools.core.routes")

local M = {}

local FILETYPES = { "ruby", "eruby", "haml", "slim" }
local VIEWS_DIR = "app/views/"
local MODELS_DIR = "app/models/"
local MIGRATIONS_DIR_PATTERN = "^db/migrate/"
local TEST_DIR_PATTERNS = { "^test/", "^spec/" }
local FIXTURE_DIRS = { "test/fixtures", "spec/fixtures" }
local DEFAULT_FORMAT = "html"
local DEFAULT_ENGINE = "erb"
local MIN_PARTS_WITH_FORMAT = 3
local ROUTE_HELPER_SUFFIXES = { "_path", "_url" }
local ALL_FIXTURES = "all"
local PARTIAL_PICKER_PROMPT = "Rails partial"
local NORMAL_COMMAND_ERROR_PATTERN = "Vim%(normal%):(.*)$"

local RENDER_PREFIX_PATTERNS = {
  "%f[%w_]render%s*%(?%s*$",
  "%f[%w_]render%f[^%w_].-partial:%s*$",
  "%f[%w_]render%f[^%w_].-:partial%s*=>%s*$",
}

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

---@class GfTarget
---@field kind "file"|"route"|"missing"
---@field paths? string[] paths relative to the Rails root, for kind "file"
---@field lnum? integer line to put the cursor on, for kind "file"
---@field notice? string message shown after opening, for kind "file"
---@field name? string route name, for kind "route"
---@field message? string what was not found, for kind "missing"

---@class GfLineContext
---@field root string Rails root
---@field file string absolute path of the current file
---@field line string current line
---@field col integer 0-indexed byte column of the cursor

---@class GfTextContext
---@field root string Rails root
---@field file string absolute path of the current file
---@field text string selected text

---@param message string
---@return GfTarget
local function missing(message)
  return { kind = "missing", message = "Rails: " .. message }
end

---@param root string
---@param file string
---@return string
local function relative_path(root, file)
  local prefix = root .. "/"
  if file:sub(1, #prefix) == prefix then
    return file:sub(#prefix + 1)
  end
  return file
end

---@param root string
---@param relative string
---@return boolean
local function exists(root, relative)
  return vim.fn.filereadable(root .. "/" .. relative) == 1
end

---@param line string
---@param col integer 0-indexed
---@return {text: string, start: integer, finish: integer}|nil
local function quoted_string_at(line, col)
  local position = col + 1
  local search_from = 1
  while true do
    local start, finish, _, text = line:find("([\"'])(.-)%1", search_from)
    if not start then
      return nil
    end
    if position >= start and position <= finish then
      return { text = text, start = start, finish = finish }
    end
    search_from = finish + 1
  end
end

---@param line string
---@param col integer 0-indexed
---@return string|nil
local function partial_name_at(line, col)
  local quoted = quoted_string_at(line, col)
  if not quoted or quoted.text == "" then
    return nil
  end
  local before = line:sub(1, quoted.start - 1)
  for _, pattern in ipairs(RENDER_PREFIX_PATTERNS) do
    if before:match(pattern) then
      return quoted.text
    end
  end
  return nil
end

---@param relative_file string
---@param name string
---@return string|nil folder under app/views
---@return string|nil partial base name
local function partial_folder_and_base(relative_file, name)
  local folder, base = name:match("^(.+)/([^/]+)$")
  if folder then
    return folder, base
  end
  local view_folder = relative_file:match("^app/views/(.+)/[^/]+$")
  if view_folder then
    return view_folder, name
  end
  local controller_path = relative_file:match("^app/controllers/(.+)_controller%.rb$")
  if controller_path then
    return controller_path, name
  end
  return nil, nil
end

---@param relative_file string
---@return string
local function format_of(relative_file)
  local parts = vim.split(vim.fn.fnamemodify(relative_file, ":t"), ".", { plain = true })
  if #parts >= MIN_PARTS_WITH_FORMAT then
    return parts[#parts - 1]
  end
  return DEFAULT_FORMAT
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

---@return string
local function first_engine_tried()
  local configured = config.get().view.engine
  if configured and configured ~= "auto" then
    return configured
  end
  return (config.get().view.priority or {})[1] or DEFAULT_ENGINE
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
local function partial_files(root, folder, base)
  local partial_prefix = VIEWS_DIR .. folder .. "/_" .. base .. "."
  local files = {}
  for _, path in ipairs(vim.fn.glob(root .. "/" .. partial_prefix .. "*", false, true)) do
    local relative = relative_path(root, path)
    local extensions = relative:sub(#partial_prefix + 1)
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

---@param root string
---@param relative_file string
---@param name string
---@return string[]|nil candidates, nil when the name cannot be placed in a views folder
---@return string|nil first path tried
local function partial_candidates(root, relative_file, name)
  local folder, base = partial_folder_and_base(relative_file, name)
  if not folder then
    return nil, nil
  end
  local format = format_of(relative_file)
  local files = partial_files(root, folder, base)
  local candidates = paths_by_engine(files, function(file_format)
    return file_format == format
  end)
  if #candidates == 0 then
    candidates = paths_by_engine(files, function(file_format)
      return file_format == nil or file_format == DEFAULT_FORMAT
    end)
  end
  return candidates, ("%s%s/_%s.%s.%s"):format(VIEWS_DIR, folder, base, format, first_engine_tried())
end

---@param root string
---@param relative_file string
---@param name string
---@return GfTarget|nil
local function partial_target(root, relative_file, name)
  local candidates, first_tried = partial_candidates(root, relative_file, name)
  if not candidates then
    return nil
  end
  if #candidates == 0 then
    return missing("partial not found: " .. first_tried)
  end
  return { kind = "file", paths = candidates }
end

---@param root string
---@param name string
---@return string|nil
local function fixture_file(root, name)
  for _, folder in ipairs(FIXTURE_DIRS) do
    local relative = ("%s/%s.yml"):format(folder, name)
    if exists(root, relative) then
      return relative
    end
  end
  return nil
end

---@param root string
---@param relative string
---@param key string
---@return integer|nil
local function fixture_key_line(root, relative, key)
  local key_pattern = "^" .. vim.pesc(key) .. ":"
  for line_number, line in ipairs(vim.fn.readfile(root .. "/" .. relative)) do
    if line:match(key_pattern) then
      return line_number
    end
  end
  return nil
end

---@param line string
---@param col integer 0-indexed
---@return string|nil
local function symbol_at(line, col)
  local position = col + 1
  local search_from = 1
  while true do
    local start, finish, name = line:find("%f[:%w_]:([%w_]+)", search_from)
    if not start then
      return nil
    end
    if position >= start and position <= finish then
      return name
    end
    search_from = finish + 1
  end
end

---@param root string
---@param line string
---@param col integer 0-indexed
---@return GfTarget|nil
local function fixtures_declaration_target(root, line, col)
  if not line:match("^%s*fixtures[%s(]") then
    return nil
  end
  local name = symbol_at(line, col)
  if not name or name == ALL_FIXTURES then
    return nil
  end
  local relative = fixture_file(root, name)
  if not relative then
    return missing(("fixture not found: %s/%s.yml"):format(FIXTURE_DIRS[1], name))
  end
  return { kind = "file", paths = { relative } }
end

---@param root string
---@param relative string
---@param key string
---@return GfTarget
local function fixture_key_target(root, relative, key)
  local key_line = fixture_key_line(root, relative, key)
  if key_line then
    return { kind = "file", paths = { relative }, lnum = key_line }
  end
  local notice = ("Rails: fixture %s not found in %s"):format(key, relative)
  return { kind = "file", paths = { relative }, lnum = 1, notice = notice }
end

---@param root string
---@param line string
---@param col integer 0-indexed
---@return GfTarget|nil
local function fixture_accessor_target(root, line, col)
  local position = col + 1
  local search_from = 1
  while true do
    local start, finish, accessor, key = line:find("%f[%w_]([%w_]+)%(%s*:([%w_]+)%s*%)", search_from)
    if not start then
      return nil
    end
    local relative = fixture_file(root, accessor)
    if relative and position >= start and position <= finish then
      return fixture_key_target(root, relative, key)
    end
    search_from = finish + 1
  end
end

---@param relative_file string
---@return boolean
local function is_test_file(relative_file)
  for _, pattern in ipairs(TEST_DIR_PATTERNS) do
    if relative_file:match(pattern) then
      return true
    end
  end
  return false
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

---@param root string
---@param table_name string
---@return string
local function model_file_for_table(root, table_name)
  for _, model_file in ipairs(vim.fn.globpath(root, MODELS_DIR .. "**/*.rb", false, true)) do
    local readable, lines = pcall(vim.fn.readfile, model_file)
    if readable and annotate.parse(lines).table_name == table_name then
      return relative_path(root, model_file)
    end
  end
  return MODELS_DIR .. model_context.singularize(table_name) .. ".rb"
end

---@param root string
---@param relative string
---@return GfTarget
local function model_target(root, relative)
  if exists(root, relative) then
    return { kind = "file", paths = { relative } }
  end
  return missing("model not found: " .. relative)
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

---@param root string
---@param line string
---@param col integer 0-indexed
---@return GfTarget|nil
local function migration_target(root, line, col)
  local method, receiver, arguments_start = migration_call(line)
  if not method then
    return nil
  end
  local position = col + 1
  for index, argument in ipairs(positional_arguments(line, arguments_start)) do
    if position >= argument.start and position <= argument.finish then
      local kind = migration_argument_kind(method, receiver, index)
      if kind == "reference" then
        return model_target(root, MODELS_DIR .. argument.name .. ".rb")
      elseif kind == "table" then
        return model_target(root, model_file_for_table(root, argument.name))
      end
      return nil
    end
  end
  return nil
end

---@param word string|nil
---@return string|nil
local function route_name_of(word)
  if not word then
    return nil
  end
  for _, suffix in ipairs(ROUTE_HELPER_SUFFIXES) do
    if #word > #suffix and word:sub(-#suffix) == suffix then
      return word:sub(1, -#suffix - 1)
    end
  end
  return nil
end

---Resolve what `gf` should open for the cursor position on `ctx.line`.
---@param ctx GfLineContext
---@return GfTarget|nil nil when no Rails context is recognized (fall back to the default gf)
function M.resolve(ctx)
  local relative_file = relative_path(ctx.root, ctx.file)

  local partial_name = partial_name_at(ctx.line, ctx.col)
  local target = partial_name and partial_target(ctx.root, relative_file, partial_name)
  if target then
    return target
  end

  if is_test_file(relative_file) then
    target = fixtures_declaration_target(ctx.root, ctx.line, ctx.col)
      or fixture_accessor_target(ctx.root, ctx.line, ctx.col)
    if target then
      return target
    end
  end

  if relative_file:match(MIGRATIONS_DIR_PATTERN) then
    target = migration_target(ctx.root, ctx.line, ctx.col)
    if target then
      return target
    end
  end

  local _, word = context.word_and_receiver(ctx.line, ctx.col)
  local route_name = route_name_of(word)
  return route_name and { kind = "route", name = route_name } or nil
end

---@param text string
---@return string
local function clean_selection(text)
  local cleaned = vim.trim(text)
  cleaned = cleaned:gsub("^[\"']", ""):gsub("[\"']$", "")
  cleaned = cleaned:gsub("^:", "")
  return cleaned
end

---Resolve what visual-mode `gf` should open for the selected text.
---@param ctx GfTextContext
---@return GfTarget|nil nil when nothing matching the text exists
function M.resolve_text(ctx)
  local text = clean_selection(ctx.text)
  if text == "" then
    return nil
  end

  local candidates = partial_candidates(ctx.root, relative_path(ctx.root, ctx.file), text)
  if candidates and #candidates > 0 then
    return { kind = "file", paths = candidates }
  end

  local fixture = fixture_file(ctx.root, text)
  if fixture then
    return { kind = "file", paths = { fixture } }
  end

  local model = model_file_for_table(ctx.root, text)
  if exists(ctx.root, model) then
    return { kind = "file", paths = { model } }
  end

  local route_name = route_name_of(text)
  return route_name and { kind = "route", name = route_name } or nil
end

---@param root string
---@param relative string
---@param target GfTarget
local function open_file(root, relative, target)
  vim.cmd.edit(vim.fn.fnameescape(root .. "/" .. relative))
  if target.lnum then
    vim.api.nvim_win_set_cursor(0, { target.lnum, 0 })
  end
  if target.notice then
    vim.notify(target.notice, vim.log.levels.INFO)
  end
end

---@param route_name string
local function open_route(route_name)
  routes.with_routes(function(parsed)
    local engine_match
    for _, route in ipairs(parsed) do
      if route.name == route_name then
        if not route.engine then
          routes.goto_action(route)
          return
        end
        engine_match = engine_match or route
      end
    end
    if engine_match then
      routes.goto_action(engine_match)
      return
    end
    vim.notify("Rails: route not found: " .. route_name, vim.log.levels.INFO)
  end)
end

---@param root string
---@param target GfTarget
local function open_target(root, target)
  if target.kind == "missing" then
    vim.notify(target.message, vim.log.levels.INFO)
  elseif target.kind == "route" then
    open_route(target.name)
  elseif #target.paths == 1 then
    open_file(root, target.paths[1], target)
  else
    vim.ui.select(target.paths, { prompt = PARTIAL_PICKER_PROMPT }, function(choice)
      if choice then
        open_file(root, choice, target)
      end
    end)
  end
end

---@param keys string
local function default_gf(keys)
  local ok, err = pcall(vim.cmd, "normal! " .. keys)
  if not ok then
    local message = tostring(err):match(NORMAL_COMMAND_ERROR_PATTERN) or tostring(err)
    vim.api.nvim_echo({ { message, "ErrorMsg" } }, true, {})
  end
end

---@return string|nil root, string file
local function current_root_and_file()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    return nil, file
  end
  return rails.root(vim.fn.fnamemodify(file, ":p:h")), file
end

local function on_normal_gf()
  local root, file = current_root_and_file()
  local target = root
    and M.resolve({
      root = root,
      file = file,
      line = vim.api.nvim_get_current_line(),
      col = vim.api.nvim_win_get_cursor(0)[2],
    })
  if not target then
    default_gf("gf")
    return
  end
  open_target(root, target)
end

---@return string
local function selected_text()
  local start_pos, end_pos = vim.fn.getpos("'<"), vim.fn.getpos("'>")
  local line = vim.fn.getline(start_pos[2])
  local end_col = end_pos[2] == start_pos[2] and math.min(end_pos[3], #line) or #line
  return line:sub(start_pos[3], end_col)
end

local function on_visual_gf()
  vim.cmd("normal! \27")
  local root, file = current_root_and_file()
  local target = root and M.resolve_text({ root = root, file = file, text = selected_text() })
  if not target then
    default_gf("gvgf")
    return
  end
  open_target(root, target)
end

---@param bufnr integer
local function attach(bufnr)
  vim.keymap.set("n", "gf", on_normal_gf, { buffer = bufnr, desc = "Go to file (Rails-aware)" })
  vim.keymap.set("x", "gf", on_visual_gf, { buffer = bufnr, desc = "Go to file (Rails-aware)" })
end

---Register the Rails-aware buffer-local `gf` for ruby, eruby, haml and slim buffers.
---Does nothing unless `modules.gf = true`.
function M.setup()
  if not config.get().modules.gf then
    return
  end

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("rails_tools_gf", { clear = true }),
    pattern = FILETYPES,
    callback = function(args)
      attach(args.buf)
    end,
  })

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.tbl_contains(FILETYPES, vim.bo[bufnr].filetype) then
      attach(bufnr)
    end
  end
end

return M

local cache = require("rails-tools.cache")
local config = require("rails-tools.config")
local rails = require("rails-tools.detectors.rails")

local M = {}

local ALL_RESOURCES = "all"
local UNLIMITED_DEPTH = math.huge

local files_cache = cache.new()

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

---@param resource any
---@return string[]|nil
local function configured_paths(resource)
  if type(resource) == "table" and type(resource.paths) == "table" then
    return resource.paths
  end
  return nil
end

---@param path string
---@param parent string
---@return boolean
local function is_inside(path, parent)
  return path:sub(1, #parent + 1) == parent .. "/"
end

---@param sorted_paths string[]
---@return string[]
local function outermost_paths(sorted_paths)
  local outermost = {}
  for _, path in ipairs(sorted_paths) do
    local is_covered = false
    for _, kept in ipairs(outermost) do
      if path == kept or is_inside(path, kept) then
        is_covered = true
        break
      end
    end
    if not is_covered then
      table.insert(outermost, path)
    end
  end
  return outermost
end

---@param resources table<string, {paths: string[]}>
---@param resource_type string
---@return string[]
local function resource_paths(resources, resource_type)
  if resource_type ~= ALL_RESOURCES then
    return configured_paths(resources[resource_type]) or {}
  end

  local paths = {}
  for _, resource in pairs(resources) do
    vim.list_extend(paths, configured_paths(resource) or {})
  end
  table.sort(paths)
  return outermost_paths(paths)
end

---@param relative_path string
---@return boolean
local function is_hidden(relative_path)
  return relative_path:match("^%.") ~= nil or relative_path:match("/%.") ~= nil
end

---@param relative_dir string
---@return boolean
local function should_descend(relative_dir)
  return not is_hidden(relative_dir)
end

---@param root string
---@param paths string[]
---@return string[]
local function scan_files(root, paths)
  local seen = {}
  local files = {}

  for _, path in ipairs(paths) do
    local dir = root .. "/" .. path
    if vim.fn.isdirectory(dir) == 1 then
      for name, entry_type in vim.fs.dir(dir, { depth = UNLIMITED_DEPTH, skip = should_descend }) do
        local relative_file = path .. "/" .. name
        if entry_type == "file" and not is_hidden(name) and not seen[relative_file] then
          seen[relative_file] = true
          table.insert(files, relative_file)
        end
      end
    end
  end

  table.sort(files)
  return files
end

---@param root string
---@param relative_file string
local function open_file(root, relative_file)
  local ok, err = pcall(vim.cmd.edit, vim.fn.fnameescape(root .. "/" .. relative_file))
  if not ok then
    vim.notify(("Rails: %s"):format(err), vim.log.levels.ERROR)
  end
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
---@param resource_type string
---@param files string[]
---@param picker_opts table
local function pick_with_telescope(root, resource_type, files, picker_opts)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local telescope_config = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers
    .new(picker_opts, {
      prompt_title = "Rails " .. resource_type,
      finder = finders.new_table({
        results = files,
        entry_maker = function(relative_file)
          return {
            value = relative_file,
            display = relative_file,
            ordinal = relative_file,
            path = root .. "/" .. relative_file,
          }
        end,
      }),
      sorter = telescope_config.generic_sorter({}),
      previewer = telescope_config.file_previewer({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection then
            open_file(root, selection.value)
          end
        end)
        return true
      end,
    })
    :find()
end

---@param root string
---@param resource_type string
---@param files string[]
local function pick_with_select(root, resource_type, files)
  vim.ui.select(files, { prompt = ("Rails %s: "):format(resource_type) }, function(choice)
    if choice then
      open_file(root, choice)
    end
  end)
end

---Open a picker listing the files of a resource type and open the chosen file
---@param resource_type string key of `finder.resources` in config, or "all"
---@param opts? {provider?: "auto"|"telescope"|"native", picker_opts?: table}
---`opts.provider` overrides `finder.provider`; `opts.picker_opts` is passed to the Telescope picker
function M.find(resource_type, opts)
  opts = opts or {}
  if not resource_type or resource_type == "" then
    vim.notify("Rails: missing resource type", vim.log.levels.WARN)
    return
  end

  local root = project_root()
  if not root then
    vim.notify("Rails: not a Rails project", vim.log.levels.WARN)
    return
  end

  local finder_config = config.get().finder
  if resource_type ~= ALL_RESOURCES and not configured_paths(finder_config.resources[resource_type]) then
    vim.notify(("Rails: unknown resource type '%s'"):format(resource_type), vim.log.levels.WARN)
    return
  end

  local paths = resource_paths(finder_config.resources, resource_type)
  files_cache.ttl = finder_config.cache_ttl
  local cache_key = table.concat({ root, resource_type, table.concat(paths, ",") }, "|")
  local files = files_cache:get(cache_key, function()
    return scan_files(root, paths)
  end)

  if #files == 0 then
    vim.notify(("Rails: no %s found"):format(resource_type), vim.log.levels.INFO)
    return
  end

  if use_telescope(opts.provider or finder_config.provider or "auto") then
    pick_with_telescope(root, resource_type, files, opts.picker_opts or {})
  else
    pick_with_select(root, resource_type, files)
  end
end

return M

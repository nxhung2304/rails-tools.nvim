local M = {}
local uv = vim.loop
local framework_detector = require("rails-tools.detectors.test_framework")
local rails = require("rails-tools.detectors.rails")
local config = require("rails-tools.config")

---@return boolean
local function has_telescope()
  local ok, _ = pcall(require, "telescope")
  return ok
end

---@param filepath string
---@return string
local function project_root(filepath)
  local dir = filepath ~= "" and vim.fn.fnamemodify(filepath, ":p:h") or nil
  return rails.root(dir) or uv.cwd()
end

---@param filepath string
---@param root string
---@return string
local function relpath(filepath, root)
  if not filepath or filepath == "" then return "" end
  if filepath:sub(1, #root + 1) == root .. '/' then
    return filepath:sub(#root + 2)
  end
  if filepath:sub(1,1) == '/' then
    return filepath:sub(2)
  end
  return filepath
end

---@param filepath string
---@param framework string|nil
---@param root string
---@return string|nil alternate_path relative to `root`
local function find_alternate(filepath, framework, root)
  local path = relpath(filepath, root)
  local maps = config.alternate_mappings(framework or "rspec")

  for _, m in ipairs(maps) do
    local from = m.from
    local to = m.to
    local res, n = path:gsub(from, to)
    if n > 0 then
      return res
    end
  end
  return nil
end

---@param filepath string
---@param framework string|nil
---@return string|nil
function M.get(filepath, framework)
  local root = project_root(filepath)
  if not framework then
    local detected = framework_detector.detect(root)
    framework = detected or "rspec"
  end
  return find_alternate(filepath, framework, root)
end

---@param root string
---@param path string relative to `root`
local function open_or_create(root, path)
  local target_abs = root .. "/" .. path

  if uv.fs_stat(target_abs) then
    vim.cmd("edit " .. vim.fn.fnameescape(target_abs))
    return
  end

  local input_choice = vim.fn.input("Create " .. path .. " ? (y/N): ")
  if input_choice:lower():match("^y") then
    vim.fn.mkdir(vim.fn.fnamemodify(target_abs, ":h"), "p")
    vim.fn.writefile({}, target_abs)
    vim.cmd("edit " .. vim.fn.fnameescape(target_abs))
  end
end

---@param root string
---@param choices table[] { path = string, label = string }
local function open_target(root, choices)
  if #choices == 0 then
    vim.notify("No alternate found", vim.log.levels.INFO)
    return
  end

  -- If only one choice, open it directly
  if #choices == 1 then
    open_or_create(root, choices[1].path)
    return
  end

  -- Multiple choices: use Telescope if available, otherwise vim.ui.select
  if has_telescope() then
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local telescope_config = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    pickers.new({}, {
      prompt_title = "Select alternate file",
      finder = finders.new_table({
        results = choices,
        entry_maker = function(choice)
          return {
            value = choice,
            display = choice.label,
            ordinal = choice.label,
          }
        end,
      }),
      sorter = telescope_config.generic_sorter(),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          open_or_create(root, selection.value.path)
        end)
        return true
      end,
    }):find()
  else
    -- Fallback to vim.ui.select
    vim.ui.select(choices, {
      prompt = "Select alternate file:",
      format_item = function(choice)
        return choice.label
      end
    }, function(choice)
      if not choice then
        return
      end
      open_or_create(root, choice.path)
    end)
  end
end

function M.open()
  local bufname = vim.api.nvim_buf_get_name(0)
  local root = project_root(bufname)
  local detected = framework_detector.detect(root)
  local choices = {}

  if detected == "both" then
    -- Find both rspec and minitest alternates
    local rspec_alt = find_alternate(bufname, "rspec", root)
    local minitest_alt = find_alternate(bufname, "minitest", root)

    if rspec_alt then
      table.insert(choices, { path = rspec_alt, label = "RSpec: " .. rspec_alt })
    end
    if minitest_alt then
      table.insert(choices, { path = minitest_alt, label = "MiniTest: " .. minitest_alt })
    end
  else
    -- Single framework or none detected
    local framework = detected or "rspec"
    local alt = find_alternate(bufname, framework, root)
    if alt then
      table.insert(choices, { path = alt, label = alt })
    end
  end

  open_target(root, choices)
end

return M

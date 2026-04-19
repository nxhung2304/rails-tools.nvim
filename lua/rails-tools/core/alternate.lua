local M = {}
local uv = vim.loop
local framework_detector = require("rails-tools.detectors.test_framework")

---@return boolean
local function has_telescope()
  local ok, _ = pcall(require, "telescope")
  return ok
end

---@param filepath string
---@return string
local function relpath(filepath)
  if not filepath or filepath == "" then return "" end
  local cwd = uv.cwd()
  if filepath:sub(1, #cwd + 1) == cwd .. '/' then
    return filepath:sub(#cwd + 2)
  end
  if filepath:sub(1,1) == '/' then
    return filepath:sub(2)
  end
  return filepath
end

---@param framework string
---@return table[]
local function get_mappings_for(framework)
  if framework == "rspec" then
    return {
      { from = [[^app/models/(.+)%.rb$]], to = "spec/models/%1_spec.rb" },
      { from = [[^app/controllers/(.+)_controller%.rb$]], to = "spec/requests/%1_spec.rb" },
      { from = [[^app/services/(.+)%.rb$]], to = "spec/services/%1_spec.rb" },
      { from = [[^app/policies/(.+)%.rb$]], to = "spec/policies/%1_spec.rb" },
      { from = [[^app/jobs/(.+)%.rb$]], to = "spec/jobs/%1_spec.rb" },
      { from = [[^app/mailers/(.+)%.rb$]], to = "spec/mailers/%1_spec.rb" },
      { from = [[^app/serializers/(.+)%.rb$]], to = "spec/serializers/%1_spec.rb" },
      { from = [[^spec/models/(.+)_spec%.rb$]], to = "app/models/%1.rb" },
      { from = [[^spec/requests/(.+)_spec%.rb$]], to = "app/controllers/%1_controller.rb" },
      { from = [[^spec/services/(.+)_spec%.rb$]], to = "app/services/%1.rb" },
      { from = [[^spec/policies/(.+)_spec%.rb$]], to = "app/policies/%1.rb" },
      { from = [[^spec/jobs/(.+)_spec%.rb$]], to = "app/jobs/%1.rb" },
      { from = [[^spec/mailers/(.+)_spec%.rb$]], to = "app/mailers/%1.rb" },
      { from = [[^spec/serializers/(.+)_spec%.rb$]], to = "app/serializers/%1.rb" },
    }
  elseif framework == "minitest" then
    return {
      { from = [[^app/models/(.+)%.rb$]], to = "test/models/%1_test.rb" },
      { from = [[^app/controllers/(.+)_controller%.rb$]], to = "test/controllers/%1_controller_test.rb" },
      { from = [[^app/services/(.+)%.rb$]], to = "test/services/%1_test.rb" },
      { from = [[^app/policies/(.+)%.rb$]], to = "test/policies/%1_test.rb" },
      { from = [[^app/jobs/(.+)%.rb$]], to = "test/jobs/%1_test.rb" },
      { from = [[^app/mailers/(.+)%.rb$]], to = "test/mailers/%1_test.rb" },
      { from = [[^app/serializers/(.+)%.rb$]], to = "test/serializers/%1_test.rb" },
      { from = [[^test/models/(.+)_test%.rb$]], to = "app/models/%1.rb" },
      { from = [[^test/controllers/(.+)_controller_test%.rb$]], to = "app/controllers/%1_controller.rb" },
      { from = [[^test/services/(.+)_test%.rb$]], to = "app/services/%1.rb" },
      { from = [[^test/policies/(.+)_test%.rb$]], to = "app/policies/%1.rb" },
      { from = [[^test/jobs/(.+)_test%.rb$]], to = "app/jobs/%1.rb" },
      { from = [[^test/mailers/(.+)_test%.rb$]], to = "app/mailers/%1.rb" },
      { from = [[^test/serializers/(.+)_test%.rb$]], to = "app/serializers/%1.rb" },
    }
  end
  return {}
end

---@param framework string|nil
---@return string|nil alternate_path
local function find_alternate(filepath, framework)
  local path = relpath(filepath)
  local maps = get_mappings_for(framework or "rspec")

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
  if not framework then
    local detected = framework_detector.detect()
    framework = detected or "rspec"
  end
  return find_alternate(filepath, framework)
end

---@param choices table[] { path = string, label = string }
local function open_target(choices)
  if #choices == 0 then
    vim.notify("No alternate found", vim.log.levels.INFO)
    return
  end

  -- If only one choice, open it directly
  if #choices == 1 then
    local choice = choices[1]
    local cwd = uv.cwd()
    local target_abs = cwd .. "/" .. choice.path

    if uv.fs_stat(target_abs) then
      vim.cmd("edit " .. target_abs)
    else
      local input_choice = vim.fn.input("Create " .. choice.path .. " ? (y/N): ")
      if input_choice:lower():match("^y") then
        local dir = target_abs:match("^(.+)/[^/]+$")
        if dir then
          os.execute("mkdir -p " .. dir)
        end
        local fh = io.open(target_abs, "w")
        if fh then fh:write("") fh:close() end
        vim.cmd("edit " .. target_abs)
      end
    end
    return
  end

  -- Multiple choices: use Telescope if available, otherwise vim.ui.select
  if has_telescope() then
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local config = require("telescope.config").values
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
      sorter = config.generic_sorter(),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)

          local choice = selection.value
          local cwd = uv.cwd()
          local target_abs = cwd .. "/" .. choice.path

          if uv.fs_stat(target_abs) then
            vim.cmd("edit " .. target_abs)
          else
            local input_choice = vim.fn.input("Create " .. choice.path .. " ? (y/N): ")
            if input_choice:lower():match("^y") then
              local dir = target_abs:match("^(.+)/[^/]+$")
              if dir then
                os.execute("mkdir -p " .. dir)
              end
              local fh = io.open(target_abs, "w")
              if fh then fh:write("") fh:close() end
              vim.cmd("edit " .. target_abs)
            end
          end
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

      local cwd = uv.cwd()
      local target_abs = cwd .. "/" .. choice.path

      if uv.fs_stat(target_abs) then
        vim.cmd("edit " .. target_abs)
      else
        local input_choice = vim.fn.input("Create " .. choice.path .. " ? (y/N): ")
        if input_choice:lower():match("^y") then
          local dir = target_abs:match("^(.+)/[^/]+$")
          if dir then
            os.execute("mkdir -p " .. dir)
          end
          local fh = io.open(target_abs, "w")
          if fh then fh:write("") fh:close() end
          vim.cmd("edit " .. target_abs)
        end
      end
    end)
  end
end

function M.open()
  local bufname = vim.api.nvim_buf_get_name(0)
  local detected = framework_detector.detect()
  local choices = {}

  if detected == "both" then
    -- Find both rspec and minitest alternates
    local rspec_alt = find_alternate(bufname, "rspec")
    local minitest_alt = find_alternate(bufname, "minitest")

    if rspec_alt then
      table.insert(choices, { path = rspec_alt, label = "RSpec: " .. rspec_alt })
    end
    if minitest_alt then
      table.insert(choices, { path = minitest_alt, label = "MiniTest: " .. minitest_alt })
    end
  else
    -- Single framework or none detected
    local framework = detected or "rspec"
    local alt = find_alternate(bufname, framework)
    if alt then
      table.insert(choices, { path = alt, label = alt })
    end
  end

  open_target(choices)
end

return M

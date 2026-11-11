local config = require("rails-tools.config")
local rails = require("rails-tools.detectors.rails")
local terminal = require("rails-tools.ui.terminal")

local M = {}

local PROMPT = "Rails runner: "
local CHARACTERWISE_MODE = "v"
local BLOCKWISE_MODE = "\22"

---@param line string
---@param col integer
---@return integer
local function last_char_end_col(line, col)
  local last_char = vim.fn.matchstr(line, ("\\%%%dc."):format(col))

  return col + math.max(#last_char, 1) - 1
end

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

---@return string
local function visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)

  if vim.fn.visualmode() == CHARACTERWISE_MODE and #lines > 0 then
    local last = #lines
    local end_col = end_pos[3] - 1
    if vim.o.selection ~= "exclusive" then
      end_col = last_char_end_col(lines[last], end_pos[3])
    end
    lines[last] = lines[last]:sub(1, end_col)
    lines[1] = lines[1]:sub(start_pos[3])
  end

  return table.concat(lines, "\n")
end

---Run Ruby code with `rails runner` in the plugin terminal
---@param code string|nil
function M.run(code)
  if not code or vim.trim(code) == "" then
    vim.notify("Rails: no code to run", vim.log.levels.WARN)
    return
  end

  local root = project_root()
  if not root then
    vim.notify("Rails: not a Rails project", vim.log.levels.WARN)
    return
  end

  if not terminal.confirm_replace() then
    return
  end

  local command = config.get().runner.command .. " " .. vim.fn.shellescape(code)
  terminal.open(command, { cwd = root })
end

---Ask for Ruby code and run it with `rails runner`
function M.run_prompt()
  vim.ui.input({ prompt = PROMPT }, function(input)
    if input == nil then
      return
    end

    M.run(input)
  end)
end

---Run the last visual selection with `rails runner`
function M.run_visual()
  if vim.fn.visualmode() == BLOCKWISE_MODE then
    vim.notify("Rails: blockwise selection is not supported", vim.log.levels.WARN)
    return
  end

  M.run(visual_selection())
end

---Run lines `line1`..`line2` of the current buffer with `rails runner`
---@param line1 integer
---@param line2 integer
function M.run_lines(line1, line2)
  M.run(table.concat(vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false), "\n"))
end

return M

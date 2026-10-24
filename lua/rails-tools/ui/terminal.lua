local config = require("rails-tools.config")
local rails = require("rails-tools.detectors.rails")

local M = {}

local state = {
  provider = nil, -- "native" | "toggleterm"
  bufnr = nil,
  winid = nil,
  job_id = nil,
  term = nil, -- toggleterm instance
}

local function get_cwd(opts)
  if opts and opts.cwd then
    return opts.cwd
  end
  return rails.root() or vim.loop.cwd()
end

local function start_job(cmd, cwd)
  local final_cmd = cmd or vim.o.shell
  if vim.fn.has("nvim-0.11") == 1 then
    return vim.fn.jobstart(final_cmd, { cwd = cwd, term = true })
  else
    return vim.fn.termopen(final_cmd, { cwd = cwd })
  end
end

local function open_window(bufnr, direction)
  local terminal_config = config.get().terminal
  local winid

  if direction == "vertical" then
    vim.cmd("botright " .. terminal_config.vertical.size .. "vsplit")
    winid = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(winid, bufnr)
    vim.wo[winid].winfixwidth = true
  elseif direction == "horizontal" then
    vim.cmd("botright " .. terminal_config.horizontal.size .. "split")
    winid = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(winid, bufnr)
    vim.wo[winid].winfixheight = true
  else -- float
    local width = math.floor(vim.o.columns * terminal_config.float.width)
    local height = math.floor(vim.o.lines * terminal_config.float.height)
    local col = math.floor((vim.o.columns - width) / 2)
    local row = math.floor((vim.o.lines - height) / 2)

    winid = vim.api.nvim_open_win(bufnr, true, {
      relative = "editor",
      style = "minimal",
      border = "rounded",
      width = width,
      height = height,
      col = col,
      row = row,
    })
  end

  return winid
end

local function clear_state()
  state.bufnr = nil
  state.winid = nil
  state.job_id = nil
  state.term = nil
  state.provider = nil
end

local function setup_cleanup(bufnr)
  vim.api.nvim_create_autocmd({ "TermClose", "BufWipeout" }, {
    buffer = bufnr,
    once = true,
    callback = function()
      if state.bufnr == bufnr then
        clear_state()
      end
    end,
  })
end

local function open_native(cmd, opts)
  local terminal_config = config.get().terminal
  local direction = (opts and opts.direction) or terminal_config.direction
  if direction ~= "float" and direction ~= "horizontal" and direction ~= "vertical" then
    direction = "float"
  end

  local cwd = get_cwd(opts)
  local bufnr = vim.api.nvim_create_buf(false, true)
  local winid = open_window(bufnr, direction)

  state.bufnr = bufnr
  state.winid = winid
  state.provider = "native"

  vim.api.nvim_win_call(winid, function()
    state.job_id = start_job(cmd, cwd)
  end)

  setup_cleanup(bufnr)
  vim.cmd("startinsert")
end

local function open_toggleterm(cmd, opts)
  local terminal_config = config.get().terminal
  local direction = (opts and opts.direction) or terminal_config.direction
  if direction ~= "float" and direction ~= "horizontal" and direction ~= "vertical" then
    direction = "float"
  end

  local cwd = get_cwd(opts)
  local toggleterm = require("toggleterm.terminal")
  local Terminal = toggleterm.Terminal

  local float_opts
  if direction == "float" then
    float_opts = {
      width = math.floor(vim.o.columns * terminal_config.float.width),
      height = math.floor(vim.o.lines * terminal_config.float.height),
    }
  end

  local term = Terminal:new({
    cmd = cmd,
    dir = cwd,
    direction = direction,
    hidden = true,
    close_on_exit = false,
    float_opts = float_opts,
  })

  state.term = term
  state.provider = "toggleterm"

  local size
  if direction == "horizontal" then
    size = terminal_config.horizontal.size
  elseif direction == "vertical" then
    size = terminal_config.vertical.size
  end

  term:open(size)
end

---@return "toggleterm"|"native"
function M.resolve_provider()
  local terminal_config = config.get().terminal
  local provider = terminal_config.provider or "auto"

  if provider == "native" then
    return "native"
  end

  local has_toggleterm = pcall(require, "toggleterm.terminal")
  if has_toggleterm then
    if provider == "toggleterm" or provider == "auto" then
      return "toggleterm"
    end
  elseif provider == "toggleterm" then
    vim.notify("Rails: toggleterm.nvim not found, falling back to native terminal", vim.log.levels.WARN)
    return "native"
  end

  return "native"
end

---@class RailsToolsTerminalOpts
---@field direction? "float"|"horizontal"|"vertical"
---@field cwd? string

---@param cmd? string
---@param opts? RailsToolsTerminalOpts
function M.open(cmd, opts)
  -- Shutdown existing terminal
  if state.provider == "toggleterm" and state.term then
    state.term:shutdown()
  elseif state.provider == "native" and state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
    vim.api.nvim_buf_delete(state.bufnr, { force = true })
  end
  clear_state()

  local provider = M.resolve_provider()
  if provider == "toggleterm" then
    open_toggleterm(cmd, opts)
  else
    open_native(cmd, opts)
  end
end

---Toggle the active terminal
function M.toggle()
  if state.provider == "toggleterm" and state.term then
    state.term:toggle()
    return
  end

  if state.provider == "native" then
    if state.winid and vim.api.nvim_win_is_valid(state.winid) then
      vim.api.nvim_win_close(state.winid, false)
      state.winid = nil
      return
    end

    if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
      local terminal_config = config.get().terminal
      state.winid = open_window(state.bufnr, terminal_config.direction)
      vim.cmd("startinsert")
      return
    end
  end

  vim.notify("Rails: no terminal to toggle", vim.log.levels.WARN)
end

---Send text to the active terminal
---@param text string
function M.send(text)
  local final_text = text
  if not text:match("\n$") then
    final_text = text .. "\n"
  end

  if state.provider == "toggleterm" and state.term then
    -- toggleterm:send might not be available or might behave differently
    -- depending on version. The spec suggests using chansend as fallback.
    if state.term.send then
      state.term:send(final_text)
    elseif state.term.job_id then
      vim.fn.chansend(state.term.job_id, final_text)
    else
      vim.notify("Rails: no active terminal", vim.log.levels.WARN)
    end
    return
  end

  if state.provider == "native" and state.job_id then
    if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
      vim.fn.chansend(state.job_id, final_text)
    else
      vim.notify("Rails: no active terminal", vim.log.levels.WARN)
    end
    return
  end

  vim.notify("Rails: no active terminal", vim.log.levels.WARN)
end

return M

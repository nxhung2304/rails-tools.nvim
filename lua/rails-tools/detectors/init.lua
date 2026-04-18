local rails = require("rails-tools.detectors.rails")

-- Phase 2+: register rspec and grape detectors here alongside rails.
---@class Detectors
local M = {}

---@return {is_rails: boolean, root: string}|nil
function M.detect()
  return rails.detect()
end

---@return string|nil
function M.root()
  return rails.root()
end

---@return boolean
function M.is_rails()
  return rails.is_rails()
end

return M

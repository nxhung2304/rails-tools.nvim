local uv = vim.loop

local M = {}

---@class RailsToolsCache
---@field ttl number seconds
---@field store table<string, {value: any, built_at: number}>
local Cache = {}
Cache.__index = Cache

---@param ttl? number seconds (default 300)
---@return RailsToolsCache
function M.new(ttl)
  return setmetatable({ ttl = ttl or 300, store = {} }, Cache)
end

---Return the cached value for `key`, rebuilding via `builder()` when
---missing or older than the cache's TTL.
---@param key string
---@param builder fun(): any
---@return any
function Cache:get(key, builder)
  local now = uv.hrtime() / 1e9
  local entry = self.store[key]
  if entry and (now - entry.built_at) < self.ttl then
    return entry.value
  end

  local value = builder()
  self.store[key] = { value = value, built_at = now }
  return value
end

---@param key string
function Cache:invalidate(key)
  self.store[key] = nil
end

function Cache:clear()
  self.store = {}
end

return M

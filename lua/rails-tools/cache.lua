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

---@param cache RailsToolsCache
---@param key string
---@return boolean
local function is_fresh(cache, key)
  local entry = cache.store[key]
  return entry ~= nil and (uv.hrtime() / 1e9 - entry.built_at) < cache.ttl
end

---Return the cached value for `key`, rebuilding via `builder()` when
---missing or older than the cache's TTL.
---@param key string
---@param builder fun(): any
---@return any
function Cache:get(key, builder)
  if is_fresh(self, key) then
    return self.store[key].value
  end

  local value = builder()
  self:set(key, value)
  return value
end

---Return the cached value for `key` when it is younger than the TTL, else nil
---@param key string
---@return any
function Cache:peek(key)
  if is_fresh(self, key) then
    return self.store[key].value
  end
  return nil
end

---Store `value` for `key`, replacing any existing entry
---@param key string
---@param value any
function Cache:set(key, value)
  self.store[key] = { value = value, built_at = uv.hrtime() / 1e9 }
end

---@param key string
function Cache:invalidate(key)
  self.store[key] = nil
end

function Cache:clear()
  self.store = {}
end

return M

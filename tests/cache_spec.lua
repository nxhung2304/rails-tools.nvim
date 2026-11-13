local cache_module = require("rails-tools.cache")

describe("cache", function()
  it("builds the value on first access", function()
    local cache = cache_module.new(300)
    local calls = 0
    local value = cache:get("k", function()
      calls = calls + 1
      return "built"
    end)
    assert.are.equal("built", value)
    assert.are.equal(1, calls)
  end)

  it("returns the cached value without rebuilding within the TTL", function()
    local cache = cache_module.new(300)
    local calls = 0
    cache:get("k", function()
      calls = calls + 1
      return calls
    end)
    local second = cache:get("k", function()
      calls = calls + 1
      return calls
    end)
    assert.are.equal(1, second)
    assert.are.equal(1, calls)
  end)

  it("rebuilds after invalidate()", function()
    local cache = cache_module.new(300)
    local calls = 0
    cache:get("k", function()
      calls = calls + 1
      return calls
    end)
    cache:invalidate("k")
    local second = cache:get("k", function()
      calls = calls + 1
      return calls
    end)
    assert.are.equal(2, second)
    assert.are.equal(2, calls)
  end)

  it("keeps separate entries per key", function()
    local cache = cache_module.new(300)
    local a = cache:get("a", function()
      return "value-a"
    end)
    local b = cache:get("b", function()
      return "value-b"
    end)
    assert.are.equal("value-a", a)
    assert.are.equal("value-b", b)
  end)

  it("rebuilds once the TTL has elapsed", function()
    local uv = vim.uv or vim.loop
    local cache = cache_module.new(0)
    local calls = 0
    cache:get("k", function()
      calls = calls + 1
      return calls
    end)
    uv.sleep(5)
    local second = cache:get("k", function()
      calls = calls + 1
      return calls
    end)
    assert.are.equal(2, second)
    assert.are.equal(2, calls)
  end)

  it("clear() drops every entry", function()
    local cache = cache_module.new(300)
    local calls = 0
    cache:get("k", function()
      calls = calls + 1
      return calls
    end)
    cache:clear()
    local second = cache:get("k", function()
      calls = calls + 1
      return calls
    end)
    assert.are.equal(2, second)
  end)

  it("peek() returns nil for a missing entry", function()
    local cache = cache_module.new(300)

    assert.is_nil(cache:peek("k"))
  end)

  it("peek() returns a value stored with set() within the TTL", function()
    local cache = cache_module.new(300)

    cache:set("k", "stored")

    assert.are.equal("stored", cache:peek("k"))
  end)

  it("peek() returns nil once the TTL has elapsed", function()
    local uv = vim.uv or vim.loop
    local cache = cache_module.new(0)
    cache:set("k", "stored")

    uv.sleep(5)

    assert.is_nil(cache:peek("k"))
  end)

  it("get() returns a value stored with set() without rebuilding", function()
    local cache = cache_module.new(300)
    cache:set("k", "stored")

    local value = cache:get("k", function()
      return "built"
    end)

    assert.are.equal("stored", value)
  end)
end)

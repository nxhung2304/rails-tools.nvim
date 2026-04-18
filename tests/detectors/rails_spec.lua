local rails

describe("rails detector", function()
  local tmp_dir
  local orig_cwd

  before_each(function()
    orig_cwd = vim.fn.getcwd()
    tmp_dir = vim.fn.tempname()
    vim.fn.mkdir(tmp_dir, "p")
    package.loaded["rails-tools.detectors.rails"] = nil
    rails = require("rails-tools.detectors.rails")
  end)

  after_each(function()
    vim.fn.delete(tmp_dir, "rf")
    vim.cmd("cd " .. orig_cwd)
  end)

  local function create_file(path)
    local full = tmp_dir .. "/" .. path
    local dir = vim.fn.fnamemodify(full, ":h")
    vim.fn.mkdir(dir, "p")
    vim.fn.writefile({}, full)
  end

  describe("detect()", function()
    it("returns result with is_rails=true for valid Rails project (bin/rails)", function()
      create_file("Gemfile")
      create_file("bin/rails")
      local result = rails.detect(tmp_dir)
      assert.is_not_nil(result)
      assert.is_true(result.is_rails)
      assert.equals(tmp_dir, result.root)
    end)

    it("returns result with is_rails=true for valid Rails project (script/rails)", function()
      create_file("Gemfile")
      create_file("script/rails")
      local result = rails.detect(tmp_dir)
      assert.is_not_nil(result)
      assert.is_true(result.is_rails)
    end)

    it("returns nil for project with Gemfile but no bin/rails", function()
      create_file("Gemfile")
      local result = rails.detect(tmp_dir)
      assert.is_nil(result)
    end)

    it("returns nil for project with bin/rails but no Gemfile", function()
      create_file("bin/rails")
      local result = rails.detect(tmp_dir)
      assert.is_nil(result)
    end)

    it("returns nil for non-Rails project", function()
      local result = rails.detect(tmp_dir)
      assert.is_nil(result)
    end)

    it("caches and reuses detection result (same table reference)", function()
      create_file("Gemfile")
      create_file("bin/rails")
      local first = rails.detect(tmp_dir)
      vim.fn.delete(tmp_dir .. "/Gemfile")
      -- cache hit returns same object, not a re-traversal
      local second = rails.detect(tmp_dir)
      assert.are.equal(first, second)
    end)

    it("negative result is cached (no re-traversal on second call)", function()
      local first = rails.detect(tmp_dir)
      assert.is_nil(first)
      -- second call should also return nil without traversal
      local second = rails.detect(tmp_dir)
      assert.is_nil(second)
    end)

    it("detects Rails root by traversing up from subdirectory", function()
      create_file("Gemfile")
      create_file("bin/rails")
      local subdir = tmp_dir .. "/app/models"
      vim.fn.mkdir(subdir, "p")
      local result = rails.detect(subdir)
      assert.is_not_nil(result)
      assert.equals(tmp_dir, result.root)
    end)

    it("two subdirs of same project share cached result", function()
      create_file("Gemfile")
      create_file("bin/rails")
      local sub1 = tmp_dir .. "/app"
      local sub2 = tmp_dir .. "/lib"
      vim.fn.mkdir(sub1, "p")
      vim.fn.mkdir(sub2, "p")
      local r1 = rails.detect(sub1)
      local r2 = rails.detect(sub2)
      -- both point to the same root-keyed cache entry
      assert.are.equal(r1, r2)
    end)
  end)

  describe("root()", function()
    it("returns root path for Rails project", function()
      create_file("Gemfile")
      create_file("bin/rails")
      vim.cmd("cd " .. tmp_dir)
      assert.equals(tmp_dir, rails.root())
    end)

    it("returns nil for non-Rails project", function()
      vim.cmd("cd " .. tmp_dir)
      assert.is_nil(rails.root())
    end)
  end)

  describe("is_rails()", function()
    it("returns true for Rails project", function()
      create_file("Gemfile")
      create_file("bin/rails")
      vim.cmd("cd " .. tmp_dir)
      assert.is_true(rails.is_rails())
    end)

    it("returns false for non-Rails project", function()
      vim.cmd("cd " .. tmp_dir)
      assert.is_false(rails.is_rails())
    end)
  end)
end)

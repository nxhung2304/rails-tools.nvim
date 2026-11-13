local detector

describe("grape detector", function()
  local tmp_dir

  before_each(function()
    tmp_dir = vim.fn.resolve(vim.fn.tempname())
    vim.fn.mkdir(tmp_dir, "p")
    package.loaded["rails-tools.detectors.grape"] = nil
    detector = require("rails-tools.detectors.grape")
  end)

  after_each(function()
    vim.fn.delete(tmp_dir, "rf")
  end)

  local function create_file(path, lines)
    local full = tmp_dir .. "/" .. path
    vim.fn.mkdir(vim.fn.fnamemodify(full, ":h"), "p")
    vim.fn.writefile(lines or {}, full)
  end

  local function create_dir(path)
    vim.fn.mkdir(tmp_dir .. "/" .. path, "p")
  end

  local function create_gemfile(gem_lines)
    local lines = { "source 'https://rubygems.org'", "gem 'rails'" }
    vim.list_extend(lines, gem_lines or {})
    create_file("Gemfile", lines)
  end

  describe("detect()", function()
    it("returns true when app/api exists and the Gemfile has the grape gem", function()
      create_dir("app/api")
      create_gemfile({ 'gem "grape", "~> 2.0"' })

      assert.is_true(detector.detect(tmp_dir))
    end)

    it("accepts single-quoted and indented grape gem lines", function()
      create_dir("app/api")
      create_gemfile({ "group :default do", "  gem 'grape'", "end" })

      assert.is_true(detector.detect(tmp_dir))
    end)

    it("returns false when app/api exists but the Gemfile has no grape gem", function()
      create_dir("app/api")
      create_gemfile()

      assert.is_false(detector.detect(tmp_dir))
    end)

    it("returns false when the Gemfile has the grape gem but app/api is missing", function()
      create_gemfile({ "gem 'grape'" })

      assert.is_false(detector.detect(tmp_dir))
    end)

    it("does not count grape extensions or commented-out lines as the grape gem", function()
      create_dir("app/api")
      create_gemfile({ "gem 'grape-entity'", "# gem 'grape'" })

      assert.is_false(detector.detect(tmp_dir))
    end)

    it("returns false when there is no Gemfile", function()
      create_dir("app/api")

      assert.is_false(detector.detect(tmp_dir))
    end)

    it("detects from a nested directory by traversing up to the Rails root", function()
      create_dir("app/api")
      create_dir("app/models")
      create_file("bin/rails")
      create_gemfile({ "gem 'grape'" })

      assert.is_true(detector.detect(tmp_dir .. "/app/models"))
    end)

    it("caches results for repeated lookups", function()
      create_dir("app/api")
      create_gemfile({ "gem 'grape'" })

      assert.is_true(detector.detect(tmp_dir))
      vim.fn.delete(tmp_dir .. "/app/api", "rf")
      assert.is_true(detector.detect(tmp_dir))
    end)
  end)
end)

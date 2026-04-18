local detector

describe("test framework detector", function()
  local tmp_dir
  local orig_cwd

  before_each(function()
    orig_cwd = vim.fn.getcwd()
    tmp_dir = vim.fn.tempname()
    vim.fn.mkdir(tmp_dir, "p")
    package.loaded["rails-tools.detectors.test_framework"] = nil
    detector = require("rails-tools.detectors.test_framework")
  end)

  after_each(function()
    vim.fn.delete(tmp_dir, "rf")
    vim.cmd("cd " .. orig_cwd)
  end)

  local function create_file(path, lines)
    local full = tmp_dir .. "/" .. path
    local dir = vim.fn.fnamemodify(full, ":h")
    vim.fn.mkdir(dir, "p")
    vim.fn.writefile(lines or {}, full)
  end

  local function create_dir(path)
    vim.fn.mkdir(tmp_dir .. "/" .. path, "p")
  end

  describe("detect()", function()
    it("returns rspec when spec directory exists", function()
      create_dir("spec")
      assert.equals("rspec", detector.detect(tmp_dir))
    end)

    it("returns minitest when test directory exists", function()
      create_dir("test")
      assert.equals("minitest", detector.detect(tmp_dir))
    end)

    it("returns nil when neither spec nor test directories exist", function()
      assert.is_nil(detector.detect(tmp_dir))
    end)

    it("returns rspec when both directories exist and Gemfile includes rspec-rails", function()
      create_dir("spec")
      create_dir("test")
      create_file("Gemfile", {
        "source 'https://rubygems.org'",
        "gem 'rails'",
        "gem 'rspec-rails'",
      })

      assert.equals("rspec", detector.detect(tmp_dir))
    end)

    it("returns minitest when both directories exist and Gemfile does not include rspec-rails", function()
      create_dir("spec")
      create_dir("test")
      create_file("Gemfile", {
        "source 'https://rubygems.org'",
        "gem 'rails'",
      })

      assert.equals("minitest", detector.detect(tmp_dir))
    end)

    it("returns minitest when both directories exist and Gemfile is missing", function()
      create_dir("spec")
      create_dir("test")

      assert.equals("minitest", detector.detect(tmp_dir))
    end)

    it("detects from a nested directory by traversing up to the project root", function()
      create_dir("spec/models")
      create_file("Gemfile", { "gem 'rspec-rails'" })
      create_dir("app/models")

      assert.equals("rspec", detector.detect(tmp_dir .. "/app/models"))
    end)

    it("caches positive results for repeated lookups", function()
      create_dir("spec")

      assert.equals("rspec", detector.detect(tmp_dir))
      vim.fn.delete(tmp_dir .. "/spec", "rf")
      assert.equals("rspec", detector.detect(tmp_dir))
    end)

    it("caches negative results for repeated lookups", function()
      assert.is_nil(detector.detect(tmp_dir))

      create_dir("spec")
      assert.is_nil(detector.detect(tmp_dir))
    end)
  end)

  describe("is_rspec()", function()
    it("returns true only for rspec projects", function()
      create_dir("spec")
      vim.cmd("cd " .. tmp_dir)

      assert.is_true(detector.is_rspec())
      assert.is_false(detector.is_minitest())
    end)
  end)

  describe("is_minitest()", function()
    it("returns true only for minitest projects", function()
      create_dir("test")
      vim.cmd("cd " .. tmp_dir)

      assert.is_true(detector.is_minitest())
      assert.is_false(detector.is_rspec())
    end)
  end)
end)

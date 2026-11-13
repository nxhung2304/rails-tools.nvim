local rspec
local config

local MODULES_TO_RELOAD = {
  "rails-tools.integrations.rspec",
  "rails-tools.config",
  "rails-tools.detectors.rails",
  "rails-tools.ui.terminal",
}

describe("rails-tools.integrations.rspec", function()
  local tmp_dir
  local orig_cwd
  local orig_notify
  local notifications
  local opened
  local replace_allowed

  local function reload_modules()
    for _, name in ipairs(MODULES_TO_RELOAD) do
      package.loaded[name] = nil
    end
  end

  local function create_file(root, path, lines)
    local full = root .. "/" .. path
    vim.fn.mkdir(vim.fn.fnamemodify(full, ":h"), "p")
    vim.fn.writefile(lines or {}, full)
    return full
  end

  local function create_rails_project(root)
    create_file(root, "Gemfile")
    create_file(root, "bin/rails")
  end

  local function edit_at_line(path, line)
    vim.cmd("edit " .. vim.fn.fnameescape(path))
    vim.api.nvim_win_set_cursor(0, { line, 0 })
  end

  before_each(function()
    orig_cwd = vim.fn.getcwd()
    tmp_dir = vim.fn.resolve(vim.fn.tempname())
    vim.fn.mkdir(tmp_dir, "p")
    reload_modules()

    notifications = {}
    orig_notify = vim.notify
    vim.notify = function(msg, level)
      table.insert(notifications, { msg = msg, level = level })
    end

    opened = {}
    replace_allowed = true
    package.loaded["rails-tools.ui.terminal"] = {
      open = function(cmd, opts)
        table.insert(opened, { cmd = cmd, cwd = opts and opts.cwd })
      end,
      confirm_replace = function()
        return replace_allowed
      end,
    }

    config = require("rails-tools.config")
    config.setup({})
    rspec = require("rails-tools.integrations.rspec")
  end)

  after_each(function()
    vim.notify = orig_notify
    vim.cmd("silent! %bwipeout!")
    vim.cmd("cd " .. vim.fn.fnameescape(orig_cwd))
    vim.fn.delete(tmp_dir, "rf")
    reload_modules()
  end)

  describe("in a spec file of a Rails project", function()
    local spec_path

    before_each(function()
      create_rails_project(tmp_dir)
      spec_path = create_file(tmp_dir, "spec/models/user_spec.rb", {
        "RSpec.describe User do",
        "  it 'works' do",
        "  end",
        "end",
      })
      edit_at_line(spec_path, 2)
    end)

    describe("run_nearest()", function()
      it("runs the spec at the cursor line from the Rails root", function()
        rspec.run_nearest()

        assert.are.same({ { cmd = "bundle exec rspec 'spec/models/user_spec.rb:2'", cwd = tmp_dir } }, opened)
      end)

      it("follows the cursor line", function()
        vim.api.nvim_win_set_cursor(0, { 4, 0 })

        rspec.run_nearest()

        assert.equals("bundle exec rspec 'spec/models/user_spec.rb:4'", opened[1].cmd)
      end)

      it("uses the rspec command from config", function()
        config.setup({ rspec = { command = "bin/rspec" } })

        rspec.run_nearest()

        assert.equals("bin/rspec 'spec/models/user_spec.rb:2'", opened[1].cmd)
      end)

      it("does not run when the user keeps the running terminal", function()
        replace_allowed = false

        rspec.run_nearest()

        assert.equals(0, #opened)
      end)
    end)

    describe("run_file()", function()
      it("runs the whole spec file from the Rails root", function()
        rspec.run_file()

        assert.are.same({ { cmd = "bundle exec rspec 'spec/models/user_spec.rb'", cwd = tmp_dir } }, opened)
      end)

      it("runs the Rails project of the spec file, not the cwd", function()
        local other_project = vim.fn.resolve(vim.fn.tempname())
        create_rails_project(other_project)
        local other_spec = create_file(other_project, "spec/jobs/sync_job_spec.rb", { "" })
        edit_at_line(other_spec, 1)

        rspec.run_file()

        assert.are.same({ cmd = "bundle exec rspec 'spec/jobs/sync_job_spec.rb'", cwd = other_project }, opened[1])
        vim.fn.delete(other_project, "rf")
      end)

      it("does not run when the user keeps the running terminal", function()
        replace_allowed = false

        rspec.run_file()

        assert.equals(0, #opened)
      end)
    end)

    describe("run_last()", function()
      it("re-runs the last spec command even from another buffer", function()
        rspec.run_nearest()
        vim.cmd("enew!")

        rspec.run_last()

        assert.equals(2, #opened)
        assert.are.same(opened[1], opened[2])
      end)

      it("re-runs the most recent of several runs", function()
        rspec.run_nearest()
        rspec.run_file()

        rspec.run_last()

        assert.are.same(opened[2], opened[3])
      end)

      it("does not remember a run the user cancelled", function()
        rspec.run_file()
        replace_allowed = false
        vim.api.nvim_win_set_cursor(0, { 3, 0 })
        rspec.run_nearest()
        replace_allowed = true

        rspec.run_last()

        assert.equals("bundle exec rspec 'spec/models/user_spec.rb'", opened[2].cmd)
      end)

      it("warns when rspec.save_last is false", function()
        config.setup({ rspec = { save_last = false } })
        rspec.run_file()

        rspec.run_last()

        assert.equals(1, #opened)
        assert.equals("Rails: no spec to re-run", notifications[1].msg)
        assert.equals(vim.log.levels.WARN, notifications[1].level)
      end)

      it("does not run when the user keeps the running terminal", function()
        rspec.run_file()
        replace_allowed = false

        rspec.run_last()

        assert.equals(1, #opened)
      end)
    end)
  end)

  describe("run_last() before any run", function()
    it("warns and runs nothing", function()
      rspec.run_last()

      assert.equals(0, #opened)
      assert.equals("Rails: no spec to re-run", notifications[1].msg)
      assert.equals(vim.log.levels.WARN, notifications[1].level)
    end)
  end)

  describe("outside a spec file", function()
    it("warns and runs nothing for a non-spec file", function()
      create_rails_project(tmp_dir)
      edit_at_line(create_file(tmp_dir, "app/models/user.rb", { "class User; end" }), 1)

      rspec.run_nearest()
      rspec.run_file()

      assert.equals(0, #opened)
      assert.equals("Rails: not a spec file", notifications[1].msg)
      assert.equals(vim.log.levels.WARN, notifications[1].level)
      assert.equals(2, #notifications)
    end)

    it("warns and runs nothing for a buffer without a file", function()
      vim.cmd("enew!")

      rspec.run_file()

      assert.equals(0, #opened)
      assert.equals("Rails: not a spec file", notifications[1].msg)
    end)

    it("warns and runs nothing for a spec file outside a Rails project", function()
      edit_at_line(create_file(tmp_dir, "spec/user_spec.rb", { "" }), 1)

      rspec.run_file()

      assert.equals(0, #opened)
      assert.equals("Rails: not a Rails project", notifications[1].msg)
      assert.equals(vim.log.levels.WARN, notifications[1].level)
    end)
  end)
end)

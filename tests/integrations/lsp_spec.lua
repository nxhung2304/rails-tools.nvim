local lsp = require("rails-tools.integrations.lsp")
local schema = require("rails-tools.core.schema")

local SAMPLE_SCHEMA = {
  'ActiveRecord::Schema[7.1].define(version: 1) do',
  '  create_table "users", force: :cascade do |t|',
  '    t.string "email", null: false',
  '  end',
  '',
  '  create_table "courses", force: :cascade do |t|',
  '    t.integer "status", default: 0, null: false',
  '  end',
  '',
  '  create_table "enrollments", force: :cascade do |t|',
  '    t.integer "status", default: 0, null: false',
  '  end',
  'end',
}

describe("integrations.lsp", function()
  local tmp_dir

  before_each(function()
    tmp_dir = vim.fn.tempname()
    vim.fn.mkdir(tmp_dir .. "/db", "p")
    vim.fn.mkdir(tmp_dir .. "/app/models", "p")
    vim.fn.writefile(SAMPLE_SCHEMA, tmp_dir .. "/db/schema.rb")
  end)

  after_each(function()
    schema.invalidate(tmp_dir)
    vim.fn.delete(tmp_dir, "rf")
  end)

  local function write_model(name, lines)
    vim.fn.writefile(lines, tmp_dir .. "/app/models/" .. name .. ".rb")
  end

  describe("hover_lines / definition_location for `user.email`", function()
    before_each(function()
      write_model("user", {
        "# == Schema Information",
        "#",
        "# Table name: users",
        "#",
        "#  email  :string not null",
        "#",
        "class User < ApplicationRecord",
        "end",
      })
    end)

    it("shows the resolved model and signature", function()
      local lines = lsp.hover_lines("user", "email", nil, tmp_dir)
      assert.is_not_nil(lines)
      assert.matches("email", lines[1])
      assert.matches("User", lines[2])
      assert.matches(":string not null", lines[2])
    end)

    it("jumps to the annotate comment line", function()
      local loc = lsp.definition_location("user", "email", nil, tmp_dir)
      assert.is_not_nil(loc)
      assert.are.equal(tmp_dir .. "/app/models/user.rb", loc.file)
      assert.are.equal(5, loc.lnum)
    end)
  end)

  describe("bare identifier (no receiver) inside the owning model", function()
    before_each(function()
      write_model("enrollment", {
        "# == Schema Information",
        "#",
        "# Table name: enrollments",
        "#",
        "#  status  :integer default(\"active\"), not null",
        "#",
        "class Enrollment < ApplicationRecord",
        "end",
      })
    end)

    it("resolves via self", function()
      local lines = lsp.hover_lines("self", "status", "Enrollment", tmp_dir)
      assert.is_not_nil(lines)
      assert.matches("Enrollment", lines[2])
    end)

    it("resolves a bare word (no receiver at all) via the current buffer's model", function()
      local lines = lsp.hover_lines(nil, "status", "Enrollment", tmp_dir)
      assert.is_not_nil(lines)
      assert.matches("Enrollment", lines[2])
    end)
  end)

  describe("cross-model column name collisions", function()
    before_each(function()
      write_model("course", {
        "# == Schema Information",
        "#",
        "# Table name: courses",
        "#",
        "#  status  :integer default(\"draft\"), not null",
        "#",
        "class Course < ApplicationRecord",
        "end",
      })
      write_model("enrollment", {
        "# == Schema Information",
        "#",
        "# Table name: enrollments",
        "#",
        "#  status  :integer default(\"active\"), not null",
        "#",
        "class Enrollment < ApplicationRecord",
        "end",
      })
    end)

    it("only shows the receiver's own model, never a sibling model with the same column", function()
      local lines = lsp.hover_lines("course", "status", "Enrollment", tmp_dir)
      assert.is_not_nil(lines)
      assert.matches("Course", lines[2])
      assert.does_not_match("Enrollment", lines[2])
    end)

    it("a bare word never leaks another model's data, even when both share the column", function()
      -- Editing inside Enrollment; a bare `status` must resolve to
      -- Enrollment only, never fall back to "every model with `status`".
      local lines = lsp.hover_lines(nil, "status", "Enrollment", tmp_dir)
      assert.is_not_nil(lines)
      assert.matches("Enrollment", lines[2])
      assert.does_not_match("Course", lines[2])
    end)

    it("returns nil for a bare word with no current-buffer model at all", function()
      assert.is_nil(lsp.hover_lines(nil, "status", nil, tmp_dir))
      assert.is_nil(lsp.definition_location(nil, "status", nil, tmp_dir))
    end)
  end)

  it("returns nil for an unrecognized column, so callers fall back to LSP hover", function()
    write_model("user", { "class User < ApplicationRecord", "end" })
    assert.is_nil(lsp.hover_lines("user", "not_a_column", nil, tmp_dir))
    assert.is_nil(lsp.definition_location("user", "not_a_column", nil, tmp_dir))
  end)

  describe("namespaced model file", function()
    before_each(function()
      vim.fn.mkdir(tmp_dir .. "/app/models/admin", "p")
      vim.fn.writefile({
        "# == Schema Information",
        "#",
        "# Table name: admin_users",
        "#",
        "#  username  :string not null",
        "#",
        "class Admin::User < ApplicationRecord",
        "end",
      }, tmp_dir .. "/app/models/admin/user.rb")
    end)

    it("resolves a bare column against the namespaced current model", function()
      local lines = lsp.hover_lines(nil, "username", "Admin::User", tmp_dir)
      assert.is_not_nil(lines)
      assert.matches("Admin::User", table.concat(lines, "\n"))
    end)

    it("does not map the receiver `user` to a namespaced model", function()
      assert.is_nil(lsp.hover_lines("user", "username", nil, tmp_dir))
    end)
  end)
end)

describe("integrations.lsp setup()", function()
  local config = require("rails-tools.config")
  local HOVER_DESC = "Hover Documentation (Rails-aware)"
  local DEFINITION_DESC = "Go to Definition (Rails-aware)"
  local buf
  local original_hover = vim.lsp.buf.hover
  local original_definition = vim.lsp.buf.definition
  local original_notify_once = vim.notify_once
  local warnings

  local function attach_ruby_buffer()
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.bo[buf].filetype = "ruby"
    return buf
  end

  local function fire_attach()
    vim.api.nvim_exec_autocmds("LspAttach", {
      group = "rails_tools_lsp_schema",
      buffer = buf,
      data = { client_id = 0 },
    })
    local flushed = false
    vim.schedule(function()
      flushed = true
    end)
    vim.wait(1000, function()
      return flushed
    end)
  end

  local function desc_of(lhs)
    return vim.fn.maparg(lhs, "n", false, true).desc
  end

  before_each(function()
    config.setup()
    lsp.setup()
    attach_ruby_buffer()
    warnings = {}
    vim.notify_once = function(message, level)
      table.insert(warnings, { message = message, level = level })
    end
  end)

  after_each(function()
    vim.notify_once = original_notify_once
    vim.lsp.buf.hover = original_hover
    vim.lsp.buf.definition = original_definition
    if buf and vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
    config.setup()
  end)

  it("maps K and gd with the Rails descs by default", function()
    fire_attach()
    assert.are.equal(HOVER_DESC, desc_of("K"))
    assert.are.equal(DEFINITION_DESC, desc_of("gd"))
    assert.are.equal(1, vim.fn.maparg("K", "n", false, true).buffer)
    assert.are.equal(1, vim.fn.maparg("gd", "n", false, true).buffer)
  end)

  it("keeps the user's own K mapping when both keys are false", function()
    config.setup({ lsp = { hover = false, definition = false } })
    vim.keymap.set("n", "K", function() end, { buffer = buf, desc = "user hover" })
    fire_attach()
    assert.are.equal("user hover", desc_of("K"))
    assert.are_not.equal(DEFINITION_DESC, desc_of("gd"))
  end)

  it("maps custom keys instead of K and gd", function()
    config.setup({ lsp = { hover = "gh", definition = "gD" } })
    fire_attach()
    assert.are.equal(HOVER_DESC, desc_of("gh"))
    assert.are.equal(DEFINITION_DESC, desc_of("gD"))
    assert.are_not.equal(HOVER_DESC, desc_of("K"))
    assert.are_not.equal(DEFINITION_DESC, desc_of("gd"))
  end)

  it("treats an empty string as no mapping", function()
    config.setup({ lsp = { hover = "", definition = "gd" } })
    fire_attach()
    assert.are_not.equal(HOVER_DESC, desc_of("K"))
    assert.are.equal(DEFINITION_DESC, desc_of("gd"))
  end)

  it("disables only the key set to false", function()
    config.setup({ lsp = { hover = false } })
    fire_attach()
    assert.are_not.equal(HOVER_DESC, desc_of("K"))
    assert.are.equal(DEFINITION_DESC, desc_of("gd"))
  end)

  it("maps nothing and raises no error when lsp = false", function()
    config.setup({ lsp = false })
    vim.v.errmsg = ""
    assert.has_no.errors(fire_attach)
    assert.are.equal("", vim.v.errmsg)
    assert.are_not.equal(HOVER_DESC, desc_of("K"))
    assert.are_not.equal(DEFINITION_DESC, desc_of("gd"))
  end)

  it("warns and maps nothing for hover when it is not a string or false", function()
    config.setup({ lsp = { hover = true } })
    fire_attach()
    assert.are.equal(1, #warnings)
    assert.matches("lsp.hover", warnings[1].message)
    assert.matches("got boolean", warnings[1].message)
    assert.are.equal(vim.log.levels.WARN, warnings[1].level)
    assert.are_not.equal(HOVER_DESC, desc_of("K"))
    assert.are.equal(DEFINITION_DESC, desc_of("gd"))
  end)

  it("warns and maps nothing when lsp is not a table or false", function()
    config.setup({ lsp = true })
    fire_attach()
    assert.are.equal(1, #warnings)
    assert.matches("lsp must be", warnings[1].message)
    assert.are_not.equal(HOVER_DESC, desc_of("K"))
    assert.are_not.equal(DEFINITION_DESC, desc_of("gd"))
  end)

  it("warns once when hover and definition share a key and the definition mapping wins", function()
    config.setup({ lsp = { hover = "gh", definition = "gh" } })
    fire_attach()
    assert.are.equal(1, #warnings)
    assert.matches("lsp.hover", warnings[1].message)
    assert.matches("lsp.definition", warnings[1].message)
    assert.matches("gh", warnings[1].message)
    assert.are.equal(vim.log.levels.WARN, warnings[1].level)
    assert.are.equal(DEFINITION_DESC, desc_of("gh"))
  end)

  it("does not warn for false or an empty string", function()
    config.setup({ lsp = { hover = false, definition = "" } })
    fire_attach()
    config.setup({ lsp = false })
    fire_attach()
    assert.are.equal(0, #warnings)
  end)

  it("exposes hover() and definition() that fall back to the LSP functions", function()
    local hover_calls, definition_calls = 0, 0
    vim.lsp.buf.hover = function()
      hover_calls = hover_calls + 1
    end
    vim.lsp.buf.definition = function()
      definition_calls = definition_calls + 1
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "foo" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    lsp.hover()
    lsp.definition()
    assert.are.equal(1, hover_calls)
    assert.are.equal(1, definition_calls)
  end)
end)

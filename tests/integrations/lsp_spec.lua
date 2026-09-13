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
end)

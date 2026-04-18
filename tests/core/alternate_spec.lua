local alternate = require("rails-tools.core.alternate")

describe("alternate.get", function()
  it("maps model to spec", function()
    assert.are.equal("spec/models/user_spec.rb", alternate.get("app/models/user.rb"))
  end)

  it("maps nested model to spec", function()
    assert.are.equal("spec/models/admin/user_spec.rb", alternate.get("app/models/admin/user.rb"))
  end)

  it("maps spec to model", function()
    assert.are.equal("app/models/user.rb", alternate.get("spec/models/user_spec.rb"))
  end)

  it("returns nil when no mapping", function()
    assert.is_nil(alternate.get("README.md"))
  end)
end)

local model_context = require("rails-tools.core.model_context")

describe("model_context.camelize", function()
  it("camelizes a simple snake_case word", function()
    assert.are.equal("User", model_context.camelize("user"))
  end)

  it("camelizes a multi-word snake_case name", function()
    assert.are.equal("OrderItem", model_context.camelize("order_item"))
  end)
end)

describe("model_context.singularize", function()
  it("leaves already-singular words unchanged", function()
    assert.are.equal("user", model_context.singularize("user"))
  end)

  it("strips a trailing s", function()
    assert.are.equal("order", model_context.singularize("orders"))
  end)

  it("does not strip ss endings", function()
    assert.are.equal("address", model_context.singularize("address"))
  end)

  it("handles ies endings", function()
    assert.are.equal("category", model_context.singularize("categories"))
  end)

  it("handles es endings after s/x/ch/sh", function()
    assert.are.equal("box", model_context.singularize("boxes"))
    assert.are.equal("class", model_context.singularize("classes"))
  end)
end)

describe("model_context.infer_model", function()
  local known_models = { User = true, Order = true, OrderItem = true }

  it("returns nil for a nil receiver", function()
    assert.is_nil(model_context.infer_model(nil, known_models, nil))
  end)

  it("resolves self to the current buffer's model", function()
    assert.are.equal("User", model_context.infer_model("self", known_models, "User"))
  end)

  it("returns nil for self outside a model file", function()
    assert.is_nil(model_context.infer_model("self", known_models, nil))
  end)

  it("resolves a variable matching a model name", function()
    assert.are.equal("User", model_context.infer_model("user", known_models, nil))
  end)

  it("resolves a plural variable via singularization", function()
    assert.are.equal("Order", model_context.infer_model("orders", known_models, nil))
  end)

  it("resolves a multi-word snake_case variable", function()
    assert.are.equal("OrderItem", model_context.infer_model("order_item", known_models, nil))
  end)

  it("falls back to the last underscore segment (e.g. current_user)", function()
    assert.are.equal("User", model_context.infer_model("current_user", known_models, nil))
  end)

  it("falls back to the current buffer's model when nothing matches", function()
    assert.are.equal("Order", model_context.infer_model("record", known_models, "Order"))
  end)

  it("returns nil when nothing matches and there is no current buffer model", function()
    assert.is_nil(model_context.infer_model("record", known_models, nil))
  end)
end)

describe("model_context.model_for_path", function()
  it("extracts the model name from an app/models path", function()
    assert.are.equal("User", model_context.model_for_path("/rails/app/models/user.rb"))
  end)

  it("camelizes multi-word filenames", function()
    assert.are.equal("OrderItem", model_context.model_for_path("app/models/order_item.rb"))
  end)

  it("returns nil for paths outside app/models", function()
    assert.is_nil(model_context.model_for_path("app/controllers/users_controller.rb"))
  end)
end)

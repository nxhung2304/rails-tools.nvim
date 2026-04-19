local alternate = require("rails-tools.core.alternate")
local framework_detector = require("rails-tools.detectors.test_framework")

describe("alternate.get", function()
  describe("with RSpec", function()
    it("maps model to spec", function()
      assert.are.equal("spec/models/user_spec.rb", alternate.get("app/models/user.rb", "rspec"))
    end)

    it("maps nested model to spec", function()
      assert.are.equal("spec/models/admin/user_spec.rb", alternate.get("app/models/admin/user.rb", "rspec"))
    end)

    it("maps controller to request spec", function()
      assert.are.equal("spec/requests/users_spec.rb", alternate.get("app/controllers/users_controller.rb", "rspec"))
    end)

    it("maps spec to model", function()
      assert.are.equal("app/models/user.rb", alternate.get("spec/models/user_spec.rb", "rspec"))
    end)

    it("maps request spec to controller", function()
      assert.are.equal("app/controllers/users_controller.rb", alternate.get("spec/requests/users_spec.rb", "rspec"))
    end)
  end)

  describe("with MiniTest", function()
    it("maps model to test", function()
      assert.are.equal("test/models/user_test.rb", alternate.get("app/models/user.rb", "minitest"))
    end)

    it("maps nested model to test", function()
      assert.are.equal("test/models/admin/user_test.rb", alternate.get("app/models/admin/user.rb", "minitest"))
    end)

    it("maps controller to controller test", function()
      assert.are.equal("test/controllers/users_controller_test.rb", alternate.get("app/controllers/users_controller.rb", "minitest"))
    end)

    it("maps test to model", function()
      assert.are.equal("app/models/user.rb", alternate.get("test/models/user_test.rb", "minitest"))
    end)

    it("maps controller test to controller", function()
      assert.are.equal("app/controllers/users_controller.rb", alternate.get("test/controllers/users_controller_test.rb", "minitest"))
    end)
  end)

  describe("other file types", function()
    it("maps service to spec (rspec)", function()
      assert.are.equal("spec/services/payment_processor_spec.rb", alternate.get("app/services/payment_processor.rb", "rspec"))
    end)

    it("maps service to test (minitest)", function()
      assert.are.equal("test/services/payment_processor_test.rb", alternate.get("app/services/payment_processor.rb", "minitest"))
    end)

    it("maps job to spec (rspec)", function()
      assert.are.equal("spec/jobs/cleanup_job_spec.rb", alternate.get("app/jobs/cleanup_job.rb", "rspec"))
    end)

    it("maps job to test (minitest)", function()
      assert.are.equal("test/jobs/cleanup_job_test.rb", alternate.get("app/jobs/cleanup_job.rb", "minitest"))
    end)

    it("maps mailer to spec (rspec)", function()
      assert.are.equal("spec/mailers/user_mailer_spec.rb", alternate.get("app/mailers/user_mailer.rb", "rspec"))
    end)

    it("maps mailer to test (minitest)", function()
      assert.are.equal("test/mailers/user_mailer_test.rb", alternate.get("app/mailers/user_mailer.rb", "minitest"))
    end)

    it("maps policy to spec (rspec)", function()
      assert.are.equal("spec/policies/user_policy_spec.rb", alternate.get("app/policies/user_policy.rb", "rspec"))
    end)

    it("maps policy to test (minitest)", function()
      assert.are.equal("test/policies/user_policy_test.rb", alternate.get("app/policies/user_policy.rb", "minitest"))
    end)

    it("maps serializer to spec (rspec)", function()
      assert.are.equal("spec/serializers/user_serializer_spec.rb", alternate.get("app/serializers/user_serializer.rb", "rspec"))
    end)

    it("maps serializer to test (minitest)", function()
      assert.are.equal("test/serializers/user_serializer_test.rb", alternate.get("app/serializers/user_serializer.rb", "minitest"))
    end)
  end)

  describe("edge cases", function()
    it("returns nil when no mapping", function()
      assert.is_nil(alternate.get("README.md", "rspec"))
    end)

    it("handles paths without framework specified (defaults to rspec)", function()
      local result = alternate.get("app/models/user.rb")
      assert.are.equal("spec/models/user_spec.rb", result)
    end)
  end)
end)

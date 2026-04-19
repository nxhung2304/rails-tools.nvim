# frozen_string_literal: true

module Admin
  class UserTest < ActiveSupport::TestCase
    test 'requires username' do
      user = ::Admin::User.new(permissions: ['users'])
      assert_not user.valid?
      assert_includes user.errors[:username], "can't be blank"
    end

    test 'requires permissions' do
      user = ::Admin::User.new(username: 'admin')
      assert_not user.valid?
      assert_includes user.errors[:permissions], "can't be blank"
    end

    test 'can_manage? returns true for permitted resources' do
      user = ::Admin::User.new(username: 'admin', permissions: %w[users posts])
      assert user.can_manage?(:users)
      assert user.can_manage?(:posts)
      assert_not user.can_manage?(:settings)
    end
  end
end

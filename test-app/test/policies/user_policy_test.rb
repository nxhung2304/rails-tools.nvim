# frozen_string_literal: true

class UserPolicyTest < ActiveSupport::TestCase
  test 'admin can destroy users' do
    admin = users(:admin)
    user = users(:one)
    policy = UserPolicy.new(admin, user)

    assert policy.destroy?
  end

  test 'regular user cannot destroy others' do
    user = users(:one)
    other = users(:two)
    policy = UserPolicy.new(user, other)

    assert_not policy.destroy?
  end

  test 'user can update themselves' do
    user = users(:one)
    policy = UserPolicy.new(user, user)

    assert policy.update?
  end
end

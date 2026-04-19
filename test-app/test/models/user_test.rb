# frozen_string_literal: true

class UserTest < ActiveSupport::TestCase
  test 'has many posts' do
    user = users(:one)
    assert_respond_to user, :posts
  end

  test 'requires email' do
    user = User.new(name: 'Test')
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test 'requires unique email' do
    existing = users(:one)
    user = User.new(email: existing.email, name: 'Test')
    assert_not user.valid?
    assert_includes user.errors[:email], 'has already been taken'
  end

  test 'full_name returns concatenated name' do
    user = User.new(first_name: 'John', last_name: 'Doe')
    assert_equal 'John Doe', user.full_name
  end

  test 'admin? returns true when admin' do
    user = User.new(admin: true)
    assert user.admin?
  end
end

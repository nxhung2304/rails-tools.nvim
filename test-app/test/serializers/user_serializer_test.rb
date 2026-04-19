# frozen_string_literal: true

class UserSerializerTest < ActiveSupport::TestCase
  test 'serializes user attributes' do
    user = users(:one)
    serializer = UserSerializer.new(user)
    json = serializer.as_json

    assert_equal user.id, json[:id]
    assert_equal user.email, json[:email]
    assert_equal user.name, json[:name]
  end
end

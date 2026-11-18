# frozen_string_literal: true

require 'test_helper'

class UserFixtureTest < ActiveSupport::TestCase
  fixtures :users

  test 'alice has an email' do
    assert_equal 'alice@example.com', users(:alice).email
  end
end

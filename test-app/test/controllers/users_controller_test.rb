# frozen_string_literal: true

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    log_in_as(@user)
  end

  test 'should get index' do
    get users_url
    assert_response :success
  end

  test 'should get show' do
    get user_url(@user)
    assert_response :success
  end

  test 'should get new' do
    get new_user_url
    assert_response :success
  end

  test 'should create user' do
    assert_difference('User.count', 1) do
      post users_url, params: { user: { email: 'test@example.com', name: 'Test User' } }
    end

    assert_redirected_to user_path(User.last)
  end

  test 'should update user' do
    patch user_url(@user), params: { user: { name: 'Updated Name' } }
    assert_redirected_to user_path(@user)
    @user.reload
    assert_equal 'Updated Name', @user.name
  end

  test 'should destroy user' do
    assert_difference('User.count', -1) do
      delete user_url(@user)
    end

    assert_redirected_to users_url
  end
end

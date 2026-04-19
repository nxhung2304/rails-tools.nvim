# frozen_string_literal: true

class UserMailerTest < ActionMailer::TestCase
  test 'welcome email' do
    user = users(:one)
    mail = UserMailer.welcome(user)

    assert_equal ['noreply@example.com'], mail.from
    assert_equal [user.email], mail.to
    assert_equal 'Welcome to our app!', mail.subject
  end

  test 'deactivation email' do
    user = users(:one)
    mail = UserMailer.deactivation(user)

    assert_equal [user.email], mail.to
    assert_equal 'Your account has been deactivated', mail.subject
  end
end

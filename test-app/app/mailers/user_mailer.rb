# frozen_string_literal: true

class UserMailer < ApplicationMailer
  default from: 'noreply@example.com'

  def welcome(user)
    @user = user
    mail(to: @user.email, subject: 'Welcome to our app!')
  end

  def deactivation(user)
    @user = user
    mail(to: @user.email, subject: 'Your account has been deactivated')
  end

  def password_reset(user)
    @user = user
    @token = user.generate_reset_token
    mail(to: @user.email, subject: 'Password reset instructions')
  end
end

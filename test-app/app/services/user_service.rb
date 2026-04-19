# frozen_string_literal: true

class UserService
  def initialize(user)
    @user = user
  end

  def deactivate
    @user.update!(active: false)
    send_deactivation_email
  end

  def promote_to_admin
    @user.update!(admin: true)
  end

  private

  def send_deactivation_email
    UserMailer.deactivation(@user).deliver_later
  end
end

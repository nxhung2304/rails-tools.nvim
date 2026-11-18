# frozen_string_literal: true

module UsersHelper
  def user_label(user)
    "#{user.name} <#{user.email}>"
  end
end

# frozen_string_literal: true

module Admin
  class UsersController < ApplicationController
    before_action :set_admin_user, only: %i[show edit update destroy]
    layout 'admin'

    def index
      @users = User.all
      @admin_users = ::Admin::User.all
    end

    def show
      # @admin_user set by before_action
    end

    def update
      if @admin_user.update(admin_user_params)
        redirect_to [:admin, @admin_user], notice: 'Admin user was successfully updated.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_admin_user
      @admin_user = ::Admin::User.find(params[:id])
    end

    def admin_user_params
      params.require(:admin_user).permit(:username, permissions: [])
    end
  end
end

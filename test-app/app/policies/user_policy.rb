# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    user.present? && (record.id == user.id || user.admin?)
  end

  def create?
    user.present?
  end

  def update?
    user.present? && (record.id == user.id || user.admin?)
  end

  def destroy?
    user&.admin?
  end

  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.where(id: user.id)
      end
    end
  end
end

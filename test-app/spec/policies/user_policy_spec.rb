# frozen_string_literal: true

RSpec.describe UserPolicy do
  let(:user) { create(:user) }
  let(:admin) { create(:user, admin: true) }
  let(:other_user) { create(:user) }

  describe 'scope' do
    it 'shows all users for admin' do
      scope = UserPolicy::Scope.new(admin, User).resolve
      expect(scope).to include(user, other_user)
    end

    it 'shows only own user for regular user' do
      scope = UserPolicy::Scope.new(user, User).resolve
      expect(scope).to include(user)
      expect(scope).not_to include(other_user)
    end
  end
end

# frozen_string_literal: true

RSpec.describe Admin::User do
  describe 'validations' do
    subject { build(:admin_user) }

    it { should validate_presence_of(:username) }
    it { should validate_uniqueness_of(:username) }
    it { should validate_presence_of(:permissions) }
  end

  describe '#can_manage?' do
    let(:admin_user) { build(:admin_user, permissions: %w[users posts]) }

    it 'returns true for permitted resources' do
      expect(admin_user.can_manage?(:users)).to be true
      expect(admin_user.can_manage?(:posts)).to be true
    end

    it 'returns false for non-permitted resources' do
      expect(admin_user.can_manage?(:settings)).to be false
    end
  end
end

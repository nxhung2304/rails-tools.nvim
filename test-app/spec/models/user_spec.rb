# frozen_string_literal: true

RSpec.describe User do
  describe 'associations' do
    it { should have_many(:posts).dependent(:destroy) }
    it { should have_one(:profile).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:user) }

    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email) }
    it { should validate_presence_of(:name) }
  end

  describe 'scopes' do
    let!(:active_user) { create(:user, active: true) }
    let!(:inactive_user) { create(:user, active: false) }

    describe '.active' do
      it 'returns only active users' do
        expect(User.active).to include(active_user)
        expect(User.active).not_to include(inactive_user)
      end
    end
  end

  describe '#full_name' do
    let(:user) { build(:user, first_name: 'John', last_name: 'Doe') }

    it 'returns concatenated name' do
      expect(user.full_name).to eq('John Doe')
    end
  end

  describe '#admin?' do
    it 'returns true when user is admin' do
      user = build(:user, admin: true)
      expect(user).to be_admin
    end

    it 'returns false when user is not admin' do
      user = build(:user, admin: false)
      expect(user).not_to be_admin
    end
  end
end

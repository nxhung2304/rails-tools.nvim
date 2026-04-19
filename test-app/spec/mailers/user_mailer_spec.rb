# frozen_string_literal: true

RSpec.describe UserMailer, type: :mailer do
  describe '.welcome' do
    let(:user) { create(:user) }
    let(:mail) { described_class.welcome(user) }

    it 'sends welcome email' do
      expect(mail.to).to eq([user.email])
      expect(mail.subject).to eq('Welcome to our app!')
    end
  end

  describe '.deactivation' do
    let(:user) { create(:user) }
    let(:mail) { described_class.deactivation(user) }

    it 'sends deactivation email' do
      expect(mail.to).to eq([user.email])
      expect(mail.subject).to eq('Your account has been deactivated')
    end
  end
end

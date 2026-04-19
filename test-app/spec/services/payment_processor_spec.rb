# frozen_string_literal: true

RSpec.describe PaymentProcessor do
  describe '#process' do
    let(:user) { create(:user, active: true) }
    let(:processor) { described_class.new(user) }

    context 'when user is active' do
      it 'processes payment successfully' do
        result = processor.process(100)
        expect(result).to be_a(Payment)
        expect(result).to be_success
      end
    end

    context 'when user is inactive' do
      let(:user) { create(:user, active: false) }

      it 'returns false' do
        result = processor.process(100)
        expect(result).to be false
      end
    end
  end
end

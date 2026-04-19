# frozen_string_literal: true

class PaymentProcessorTest < ActiveSupport::TestCase
  test 'processes payment for active user' do
    user = users(:one)
    user.update!(active: true)
    processor = PaymentProcessor.new(user)

    result = processor.process(100)

    assert result.is_a?(Payment)
    assert result.success?
  end

  test 'returns false for inactive user' do
    user = users(:one)
    user.update!(active: false)
    processor = PaymentProcessor.new(user)

    result = processor.process(100)

    assert_not result
  end
end

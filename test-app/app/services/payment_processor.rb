# frozen_string_literal: true

class PaymentProcessor
  def initialize(user)
    @user = user
  end

  def process(amount)
    return false unless @user.active?

    transaction = create_transaction(amount)
    transaction.success? ? transaction : false
  end

  private

  def create_transaction(amount)
    Payment.create!(user: @user, amount: amount, status: :pending)
  end
end

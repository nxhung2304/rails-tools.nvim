# frozen_string_literal: true

RSpec.describe UserSerializer do
  let(:user) { create(:user) }

  it 'serializes user attributes' do
    json = described_class.new(user).as_json
    expect(json[:id]).to eq(user.id)
    expect(json[:email]).to eq(user.email)
    expect(json[:name]).to eq(user.name)
  end
end

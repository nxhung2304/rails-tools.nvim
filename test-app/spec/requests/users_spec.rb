# frozen_string_literal: true

RSpec.describe 'Users API', type: :request do
  describe 'GET /users' do
    it 'returns a list of users' do
      get users_path, headers: auth_headers
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /users/:id' do
    let(:user) { create(:user) }

    it 'returns the user' do
      get user_path(user), headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(json[:id]).to eq(user.id)
    end
  end

  describe 'POST /users' do
    let(:valid_params) { { user: attributes_for(:user) } }

    it 'creates a new user' do
      expect {
        post users_path, params: valid_params, headers: auth_headers
      }.to change(User, :count).by(1)

      expect(response).to have_http_status(:created)
    end
  end
end

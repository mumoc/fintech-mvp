require "rails_helper"

RSpec.describe "Api::V1::Auth::Sessions", type: :request do
  describe "POST /api/v1/login" do
    let!(:user) { create(:user, email: "agent@example.com", password: "password123") }

    it "returns 200 and a usable JWT for valid credentials" do
      post "/api/v1/login", params: { email: "agent@example.com", password: "password123" }, as: :json

      expect(response).to have_http_status(:ok)
      token = response.parsed_body["token"]
      expect(token).to be_present

      payload = JsonWebToken.decode(token)
      expect(payload["sub"]).to eq(user.id)
      expect(payload["role"]).to eq("operator")
    end

    it "returns 401 for a wrong password" do
      post "/api/v1/login", params: { email: "agent@example.com", password: "wrong" }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).not_to have_key("token")
    end

    it "returns 401 for an unknown email" do
      post "/api/v1/login", params: { email: "ghost@example.com", password: "password123" }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end

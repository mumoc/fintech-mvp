require "rails_helper"

RSpec.describe "Api::V1::Profiles (protected endpoint)", type: :request do
  let(:user) { create(:user) }

  def auth_headers(token)
    { "Authorization" => "Bearer #{token}" }
  end

  it "returns 401 without a token" do
    get "/api/v1/me"

    expect(response).to have_http_status(:unauthorized)
  end

  it "returns 200 and the current user with a valid token" do
    token = JsonWebToken.encode({ sub: user.id, role: user.role })

    get "/api/v1/me", headers: auth_headers(token)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["email"]).to eq(user.email)
  end

  it "returns 401 for a tampered token" do
    token = JsonWebToken.encode({ sub: user.id, role: user.role })

    get "/api/v1/me", headers: auth_headers("#{token}-tampered")

    expect(response).to have_http_status(:unauthorized)
  end

  it "returns 401 for an expired token" do
    token = JsonWebToken.encode({ sub: user.id, role: user.role }, exp: 1.hour.ago)

    get "/api/v1/me", headers: auth_headers(token)

    expect(response).to have_http_status(:unauthorized)
  end
end

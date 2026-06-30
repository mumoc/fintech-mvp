require "rails_helper"

RSpec.describe "Api::V1::Countries", type: :request do
  it "returns the supported country catalog" do
    get "/api/v1/countries", headers: auth_headers(create(:user))

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["data"]).to include("code" => "MX", "document_type" => "CURP")
  end

  it "requires authentication" do
    get "/api/v1/countries"

    expect(response).to have_http_status(:unauthorized)
  end
end

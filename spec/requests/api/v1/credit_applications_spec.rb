require "rails_helper"

RSpec.describe "Api::V1::CreditApplications", type: :request do
  let(:operator) { create(:user, role: :operator) }
  let(:valid_curp) { "HEGG560427MVZRRL04" }

  def post_create(attrs, user: operator)
    post "/api/v1/credit_applications",
         params: { credit_application: attrs },
         headers: auth_headers(user),
         as: :json
  end

  def valid_attrs(overrides = {})
    {
      country: "MX",
      full_name: "Juana Pérez",
      document_number: valid_curp,
      amount_requested: 100_000,
      monthly_income: 25_000
    }.merge(overrides)
  end

  it "requires authentication" do
    post "/api/v1/credit_applications", params: { credit_application: valid_attrs }, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it "creates an application and its bank record (201)" do
    expect { post_create(valid_attrs) }.to change(BankRecord, :count).by(1)

    expect(response).to have_http_status(:created)
    body = response.parsed_body
    expect(body["country"]).to eq("MX")
    expect(body["status"]).to eq("received")
    expect(CreditApplication.find(body["id"]).bank_record).to be_present
  end

  it "returns 422 for an invalid document" do
    post_create(valid_attrs(document_number: "NOT-A-CURP"))

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["error"]).to eq("invalid_document")
  end

  it "returns 422 for an unsupported country" do
    post_create(valid_attrs(country: "ZZ"))

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["error"]).to eq("unsupported_country")
  end

  it "flags an over-leveraged application for review" do
    post_create(valid_attrs(amount_requested: 1_000_000, monthly_income: 25_000))

    expect(response).to have_http_status(:created)
    body = response.parsed_body
    expect(body["status"]).to eq("under_review")
    expect(body["flags"]).to include("requires_review" => true)
  end

  it "omits PII from an operator's response" do
    post_create(valid_attrs)

    body = response.parsed_body
    expect(body).not_to have_key("document_number")
    expect(body).not_to have_key("monthly_income")
  end
end

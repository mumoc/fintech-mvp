require "rails_helper"

# Proves ES flows through the EXISTING controller/service/jobs unchanged — only
# app/countries/es/ + one registry line were added.
RSpec.describe "ES via the existing pipeline", type: :request do
  let(:operator) { create(:user, role: :operator) }

  def create_es(attrs = {})
    body = {
      country: "ES", full_name: "Carlos Ruiz", document_number: "12345678Z",
      amount_requested: 10_000, monthly_income: 4_000
    }.merge(attrs)
    post "/api/v1/credit_applications",
         params: { credit_application: body }, headers: auth_headers(operator), as: :json
  end

  it "creates an ES application using the ES provider + normalizer" do
    create_es

    expect(response).to have_http_status(:created)
    application = CreditApplication.find(response.parsed_body["id"])
    expect(application.document_type).to eq("DNI")
    expect(application.bank_record.provider).to eq("ES_PROVIDER")
    expect(application.bank_record.account_status).to be_in(%w[active delinquent unknown])
  end

  it "rejects an invalid DNI with 422" do
    create_es(document_number: "12345678A")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["error"]).to eq("invalid_document")
  end

  it "routes an over-threshold amount to review" do
    create_es(amount_requested: 60_000)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body["status"]).to eq("under_review")
    expect(response.parsed_body["flags"]).to include("requires_review" => true)
  end
end

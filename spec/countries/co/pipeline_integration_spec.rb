require "rails_helper"

RSpec.describe "CO via the existing pipeline", type: :request do
  let(:operator) { create(:user, role: :operator) }

  def create_co(attrs = {})
    body = {
      country: "CO", full_name: "Camila Rojas", document_number: "1020304050",
      amount_requested: 20_000_000, monthly_income: 3_000_000
    }.merge(attrs)
    post "/api/v1/credit_applications",
         params: { credit_application: body }, headers: auth_headers(operator), as: :json
  end

  it "creates a CO application using the CO provider + normalizer" do
    create_co

    expect(response).to have_http_status(:created)
    application = CreditApplication.find(response.parsed_body["id"])
    expect(application.document_type).to eq("Cédula de Ciudadanía")
    expect(application.bank_record.provider).to eq("CO_PROVIDER")
    expect(application.bank_record.account_status).to be_in(%w[active delinquent unknown])
  end

  it "rejects a malformed cedula with 422" do
    create_co(document_number: "123456789")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["error"]).to eq("invalid_document")
  end

  it "routes an over-threshold amount to review" do
    create_co(amount_requested: 100_000_000)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body["status"]).to eq("under_review")
    expect(response.parsed_body["flags"]).to include("requires_review" => true)
  end
end

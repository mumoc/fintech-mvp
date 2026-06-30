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

  describe "GET /api/v1/credit_applications/:id" do
    it "returns the application with its bank summary (200)" do
      application = create(:credit_application, :with_bank_record)

      get "/api/v1/credit_applications/#{application.id}", headers: auth_headers(operator)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["id"]).to eq(application.id)
      expect(body["bank_record"]).to include("provider", "credit_score")
    end

    it "returns 404 for a missing application" do
      get "/api/v1/credit_applications/#{SecureRandom.uuid}", headers: auth_headers(operator)

      expect(response).to have_http_status(:not_found)
    end

    it "serves a repeated read from cache (serializer runs once)" do
      application = create(:credit_application, :with_bank_record)

      expect(CreditApplicationSerializer).to receive(:new).once.and_call_original

      2.times { get "/api/v1/credit_applications/#{application.id}", headers: auth_headers(operator) }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /api/v1/credit_applications" do
    it "filters by country" do
      create(:credit_application, country: "MX")
      create(:credit_application, country: "ES")

      get "/api/v1/credit_applications", params: { country: "MX" }, headers: auth_headers(operator)

      expect(response).to have_http_status(:ok)
      countries = response.parsed_body["data"].map { |a| a["country"] }.uniq
      expect(countries).to eq([ "MX" ])
    end

    it "paginates the results" do
      create_list(:credit_application, 3)

      get "/api/v1/credit_applications", params: { per_page: 2 }, headers: auth_headers(operator)

      body = response.parsed_body
      expect(body["data"].size).to eq(2)
      expect(body["meta"]).to include("page" => 1, "per_page" => 2, "total" => 3, "total_pages" => 2)
    end

    it "does not trigger N+1 queries when serializing bank records" do
      create_list(:credit_application, 3, :with_bank_record)

      # Bullet raises in the test env on N+1; a clean 200 proves bank_record is
      # eager-loaded.
      get "/api/v1/credit_applications", headers: auth_headers(operator)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"].first["bank_record"]).to be_present
    end
  end

  describe "PATCH /api/v1/credit_applications/:id/status" do
    let(:analyst) { create(:user, role: :analyst) }

    def patch_status(application, attrs, user: analyst)
      patch "/api/v1/credit_applications/#{application.id}/status",
            params: { credit_application: attrs },
            headers: auth_headers(user),
            as: :json
    end

    it "performs a valid transition (200) and records it" do
      application = create(:credit_application, status: "received")

      expect { patch_status(application, { event: "approve", lock_version: application.lock_version }) }
        .to change(StateTransition, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["status"]).to eq("approved")
    end

    it "returns 422 for an invalid transition and leaves state unchanged" do
      application = create(:credit_application, status: "approved")

      patch_status(application, { event: "start_review", lock_version: application.lock_version })

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to eq("invalid_transition")
      expect(application.reload.status).to eq("approved")
    end

    it "broadcasts the change over ActionCable" do
      application = create(:credit_application, status: "received")

      expect { patch_status(application, { event: "approve", lock_version: application.lock_version }) }
        .to have_broadcasted_to("applications")
    end

    it "returns 409 on a stale lock_version" do
      application = create(:credit_application, status: "received")
      CreditApplication.find(application.id).update!(risk_score: 1) # bump lock_version

      patch_status(application, { event: "approve", lock_version: 0 })

      expect(response).to have_http_status(:conflict)
    end

    it "forbids an operator from changing status (403)" do
      application = create(:credit_application, status: "received")

      patch_status(application, { event: "approve", lock_version: application.lock_version }, user: operator)

      expect(response).to have_http_status(:forbidden)
    end
  end
end

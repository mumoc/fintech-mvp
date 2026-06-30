require "rails_helper"

RSpec.describe "Api::V1::Webhooks (inbound bank confirmation)", type: :request do
  let(:application) { create(:credit_application) }

  def post_bank(payload, signature: nil)
    body = payload.to_json
    post "/api/v1/webhooks/bank",
         params: body,
         headers: {
           "X-Webhook-Signature" => signature || WebhookSignature.sign(body),
           "CONTENT_TYPE" => "application/json"
         }
  end

  it "rejects an invalid signature with 401" do
    post_bank({ idempotency_key: "k1", application_id: application.id }, signature: "wrong")

    expect(response).to have_http_status(:unauthorized)
    expect(WebhookEvent.count).to eq(0)
  end

  it "processes a valid webhook and mutates the application" do
    post_bank({ idempotency_key: "k2", application_id: application.id, event: "bank_confirmation" })

    expect(response).to have_http_status(:ok)
    expect(WebhookEvent.where(idempotency_key: "k2").count).to eq(1)
    expect(application.reload.flags).to include("bank_confirmed" => true)
  end

  it "is idempotent: a replayed idempotency_key is processed only once" do
    payload = { idempotency_key: "k3", application_id: application.id }

    post_bank(payload)
    expect(response).to have_http_status(:ok)
    post_bank(payload)
    expect(response).to have_http_status(:ok)

    expect(WebhookEvent.where(idempotency_key: "k3").count).to eq(1)
    # The audit trigger records exactly one UPDATE — the mutation ran once.
    expect(AuditLog.where(record_id: application.id, action: "UPDATE").count).to eq(1)
  end
end

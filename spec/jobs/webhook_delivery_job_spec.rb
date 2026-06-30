require "rails_helper"

RSpec.describe WebhookDeliveryJob do
  let(:application) { create(:credit_application, status: "approved") }

  it "posts a signed payload and records a delivered webhook" do
    posted_body = nil
    posted_headers = nil
    allow(Webhooks::Client).to receive(:post) do |_url, body, headers|
      posted_body = body
      posted_headers = headers
      Webhooks::Client::Response.new(code: 200, body: "ok")
    end

    expect { described_class.new.perform(application.id) }.to change(WebhookDelivery, :count).by(1)

    expect(JSON.parse(posted_body)).to include("application_id" => application.id, "status" => "approved")
    expect(posted_headers).to have_key("X-Webhook-Signature")
    expect(WebhookDelivery.last.status).to eq("delivered")
  end

  it "records a failed delivery and raises (Sidekiq retries) on a non-2xx response" do
    allow(Webhooks::Client).to receive(:post)
      .and_return(Webhooks::Client::Response.new(code: 500, body: "err"))

    expect { described_class.new.perform(application.id) }
      .to raise_error(WebhookDeliveryJob::DeliveryError)

    expect(WebhookDelivery.last.status).to eq("failed")
  end

  it "records a failure and raises on a network error" do
    allow(Webhooks::Client).to receive(:post).and_raise(Errno::ECONNREFUSED)

    expect { described_class.new.perform(application.id) }.to raise_error(StandardError)
    expect(WebhookDelivery.last.status).to eq("failed")
  end
end

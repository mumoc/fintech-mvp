require "rails_helper"

RSpec.describe Applications::Broadcaster do
  it "broadcasts a non-PII payload to the applications stream" do
    application = create(:credit_application, full_name: "Top Secret Name", document_number: "HEGG560427MVZRRL04")

    expect { described_class.application_changed(application, event: "status_changed") }
      .to have_broadcasted_to(ApplicationsChannel::STREAM)
      .with { |data|
        expect(data["event"]).to eq("status_changed")
        expect(data["application"]["id"]).to eq(application.id)
        expect(data["application"]).not_to have_key("full_name")
        expect(data["application"]).not_to have_key("document_number")
        expect(data["application"]).not_to have_key("monthly_income")
      }
  end
end

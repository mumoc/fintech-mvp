require "rails_helper"

RSpec.describe Applications::CachedView do
  let(:user) { build(:user, role: :analyst) }

  it "serves the second read from cache (serializer runs once)" do
    application = create(:credit_application, :with_bank_record)

    expect(CreditApplicationSerializer).to receive(:new).once.and_call_original

    described_class.fetch(application, user: user)
    described_class.fetch(application, user: user)
  end

  it "invalidates automatically when the record changes (updated_at)" do
    application = create(:credit_application)
    described_class.fetch(application, user: user) # warm the cache

    application.update!(status: "approved") # updated_at changes -> new key

    expect(CreditApplicationSerializer).to receive(:new).once.and_call_original
    result = described_class.fetch(application, user: user)
    expect(result[:status]).to eq("approved")
  end

  it "does not share an operator's redacted view with an analyst" do
    application = create(:credit_application)

    operator_view = described_class.fetch(application, user: build(:user, role: :operator))
    analyst_view = described_class.fetch(application, user: build(:user, role: :analyst))

    expect(operator_view).not_to have_key(:document_number)
    expect(analyst_view).to have_key(:document_number)
  end
end

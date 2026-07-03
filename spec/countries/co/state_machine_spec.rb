require "rails_helper"

RSpec.describe Countries::CO::StateMachine do
  it "routes an over-leveraged application to review" do
    application = build(:credit_application, amount_requested: 100_000_000, monthly_income: 3_000_000)

    decision = described_class.new(application).intake

    expect(decision.status).to eq("under_review")
    expect(decision.flags).to include("requires_review" => true)
  end

  it "keeps an application within the income ratio as received" do
    application = build(:credit_application, amount_requested: 30_000_000, monthly_income: 3_000_000)

    decision = described_class.new(application).intake

    expect(decision.status).to eq("received")
    expect(decision.flags).to eq({})
  end
end

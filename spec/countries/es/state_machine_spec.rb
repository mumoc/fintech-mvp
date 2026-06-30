require "rails_helper"

RSpec.describe Countries::ES::StateMachine do
  describe "#intake" do
    it "routes an amount over the threshold to review" do
      application = build(:credit_application, country: "ES", amount_requested: 60_000)

      decision = described_class.new(application).intake

      expect(decision.status).to eq("under_review")
      expect(decision.flags).to include("requires_review" => true)
    end

    it "keeps an amount under the threshold at the initial state" do
      application = build(:credit_application, country: "ES", amount_requested: 10_000)

      expect(described_class.new(application).intake.status).to eq("received")
    end
  end

  it "inherits the shared transition graph (received -> approved)" do
    machine = described_class.new(build(:credit_application, country: "ES", status: "received"))

    expect(machine.may_approve?).to be(true)
  end
end

require "rails_helper"

RSpec.describe Countries::MX::StateMachine do
  def machine_for(status)
    described_class.new(build(:credit_application, status: status))
  end

  describe "transition graph" do
    it "allows received -> approved" do
      machine = machine_for("received")

      expect(machine.may_approve?).to be(true)
      machine.approve!
      expect(machine.aasm.current_state).to eq(:approved)
    end

    it "allows received -> under_review" do
      expect(machine_for("received").may_start_review?).to be(true)
    end

    it "forbids approved -> under_review" do
      expect(machine_for("approved").may_start_review?).to be(false)
    end

    it "forbids transitions out of a terminal state" do
      expect(machine_for("rejected").may_approve?).to be(false)
    end
  end

  describe "#intake" do
    it "routes an over-leveraged application to review" do
      application = build(:credit_application, amount_requested: 1_000_000, monthly_income: 25_000)

      decision = described_class.new(application).intake

      expect(decision.status).to eq("under_review")
      expect(decision.flags).to include("requires_review" => true)
    end

    it "keeps a healthy application at the initial state" do
      application = build(:credit_application, amount_requested: 100_000, monthly_income: 25_000)

      expect(described_class.new(application).intake.status).to eq("received")
    end
  end
end

require "rails_helper"

RSpec.describe Applications::UpdateStatus do
  let(:actor) { create(:user, role: :analyst) }

  it "performs a valid transition and records it" do
    application = create(:credit_application, status: "received")

    result = nil
    expect { result = described_class.call!(application: application, event: "approve", actor: actor, reason: "ok") }
      .to change(StateTransition, :count).by(1)

    expect(result).to be_success
    expect(application.reload.status).to eq("approved")

    transition = StateTransition.last
    expect(transition.from_state).to eq("received")
    expect(transition.to_state).to eq("approved")
    expect(transition.actor).to eq(actor)
  end

  it "rejects an invalid transition and leaves the state unchanged" do
    application = create(:credit_application, status: "approved")

    result = nil
    expect { result = described_class.call!(application: application, event: "start_review") }
      .not_to change(StateTransition, :count)

    expect(result).to be_failure
    expect(result.error.code).to eq(:invalid_transition)
    expect(application.reload.status).to eq("approved")
  end

  it "returns a conflict on a stale lock_version" do
    application = create(:credit_application, status: "received")
    # Simulate a concurrent update bumping the persisted lock_version.
    CreditApplication.find(application.id).update!(risk_score: 1)

    result = described_class.call!(application: application, event: "approve", expected_lock_version: 0)

    expect(result).to be_failure
    expect(result.error.code).to eq(:conflict)
    expect(application.reload.status).to eq("received")
  end
end

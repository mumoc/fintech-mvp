require "rails_helper"

RSpec.describe Outbox::Dispatcher do
  it "enqueues the matching job for a created event and marks it processed" do
    application = create(:credit_application) # trigger emits a 'created' event

    expect { described_class.new.drain }.to change { RiskEvaluationJob.jobs.size }.by(1)

    expect(RiskEvaluationJob.jobs.last["args"]).to eq([ application.id ])
    expect(OutboxEvent.pending.where(aggregate_id: application.id).count).to eq(0)
  end

  it "marks each pending event processed exactly once" do
    create(:credit_application, status: "received").update!(status: "approved")
    expect(OutboxEvent.pending.count).to eq(2) # created + status_changed

    described_class.new.drain

    expect(OutboxEvent.pending.count).to eq(0)
    expect(OutboxEvent.where.not(processed_at: nil).count).to eq(2)
  end

  it "does not re-process already-processed events" do
    create(:credit_application)
    described_class.new.drain

    expect { described_class.new.drain }.not_to change { RiskEvaluationJob.jobs.size }
  end
end

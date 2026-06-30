require "rails_helper"

RSpec.describe "outbox trigger", type: :model do
  it "emits one 'created' event when an application is inserted" do
    application = create(:credit_application)

    events = OutboxEvent.where(aggregate_id: application.id, event_type: "created")
    expect(events.count).to eq(1)
    expect(events.first.aggregate_type).to eq("CreditApplication")
  end

  it "emits exactly one 'status_changed' event per status change, in the same tx" do
    application = create(:credit_application, status: "received")

    expect { application.update!(status: "approved") }
      .to change { OutboxEvent.where(aggregate_id: application.id, event_type: "status_changed").count }
      .by(1)

    payload = OutboxEvent.where(event_type: "status_changed").last.payload
    expect(payload).to include("from" => "received", "to" => "approved")
  end

  it "does not emit an event for non-status updates" do
    application = create(:credit_application)

    expect { application.update!(risk_score: 5) }.not_to change(OutboxEvent, :count)
  end

  it "rolls back the event with the transaction (atomic with the state change)" do
    application = create(:credit_application, status: "received")
    before = OutboxEvent.count

    ActiveRecord::Base.transaction do
      application.update!(status: "approved")
      raise ActiveRecord::Rollback
    end

    expect(OutboxEvent.count).to eq(before)
    expect(application.reload.status).to eq("received")
  end
end

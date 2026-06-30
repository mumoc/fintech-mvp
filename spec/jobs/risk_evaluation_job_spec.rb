require "rails_helper"

RSpec.describe RiskEvaluationJob do
  it "writes a risk score within range" do
    application = create(:credit_application, :with_bank_record)
    expect(application.risk_score).to be_nil

    described_class.new.perform(application.id)

    expect(application.reload.risk_score).to be_between(0, 100)
  end

  it "is idempotent: running twice yields a single effect" do
    application = create(:credit_application, :with_bank_record)
    described_class.new.perform(application.id)
    first_score = application.reload.risk_score

    expect { described_class.new.perform(application.id) }
      .not_to change { application.reload.risk_score }

    expect(application.reload.risk_score).to eq(first_score)
    # The audit trigger records one UPDATE — proof of a single write.
    expect(AuditLog.where(record_id: application.id, action: "UPDATE").count).to eq(1)
  end

  it "logs structured JSON with the required keys and no PII" do
    io = StringIO.new
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)
    begin
      application = create(
        :credit_application, :with_bank_record,
        full_name: "Juana Secreta", document_number: "HEGG560427MVZRRL04"
      )
      described_class.new.perform(application.id)
    ensure
      Rails.logger = original_logger
    end

    completed = io.string.lines.find { |line| line.include?("risk_evaluation.completed") }
    expect(completed).to be_present

    json = JSON.parse(completed[/\{.*\}/])
    expect(json).to include("event", "country", "application_id", "risk_score")
    expect(io.string).not_to include("Juana Secreta")
    expect(io.string).not_to include("HEGG560427MVZRRL04")
  end
end

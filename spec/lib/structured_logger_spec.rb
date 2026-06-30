require "rails_helper"

RSpec.describe StructuredLogger do
  let(:io) { StringIO.new }
  let(:logger) { described_class.new(ActiveSupport::Logger.new(io)) }

  def last_json
    JSON.parse(io.string.lines.last[/\{.*\}/])
  end

  it "emits JSON with the mandatory keys" do
    logger.info(event: "thing.happened", application_id: "abc-123", country: "MX")

    expect(last_json).to include(
      "event" => "thing.happened", "application_id" => "abc-123", "country" => "MX"
    )
  end

  it "strips PII keys from the extra payload" do
    logger.info(
      event: "x", application_id: "abc-123", country: "MX",
      document_number: "SECRETDOC", monthly_income: 9999, full_name: "Secret Name",
      risk_score: 42
    )

    expect(io.string).not_to include("SECRETDOC")
    expect(io.string).not_to include("Secret Name")
    expect(last_json).not_to include("document_number", "monthly_income", "full_name")
    expect(last_json).to include("risk_score" => 42)
  end
end

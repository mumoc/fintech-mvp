require "rails_helper"

RSpec.describe Countries::MX::BankProvider do
  let(:application) { Struct.new(:document_number).new("HEGG560427MVZRRL04") }

  it "returns the MX provider shape" do
    payload = described_class.new.fetch(application)

    expect(payload).to include("deuda_total", "buro_score", "estatus_cuenta")
    expect(payload["proveedor"]).to eq("MX_PROVIDER")
  end

  it "is deterministic for the same document" do
    first = described_class.new.fetch(application)
    second = described_class.new.fetch(application)

    expect(first).to eq(second)
  end

  it "produces a credit score within the bureau range" do
    payload = described_class.new.fetch(application)

    expect(payload["buro_score"]).to be_between(300, 850)
  end
end

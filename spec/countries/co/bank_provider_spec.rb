require "rails_helper"

RSpec.describe Countries::CO::BankProvider do
  let(:application) do
    Struct.new(:document_number, :monthly_income).new("1020304050", 3_000_000)
  end

  it "returns the CO provider shape" do
    payload = described_class.new.fetch(application)

    expect(payload).to include("deuda_bancaria", "puntaje", "estado_producto")
    expect(payload["proveedor"]).to eq("CO_PROVIDER")
  end

  it "is deterministic for the same document and income" do
    first = described_class.new.fetch(application)
    second = described_class.new.fetch(application)

    expect(first).to eq(second)
  end

  it "produces a credit score within the bureau range" do
    payload = described_class.new.fetch(application)

    expect(payload["puntaje"]).to be_between(300, 850)
  end

  it "lowers the score when debt is high relative to income" do
    low_income = Struct.new(:document_number, :monthly_income).new("1020304050", 500_000)
    high_income = Struct.new(:document_number, :monthly_income).new("1020304050", 5_000_000)

    expect(described_class.new.fetch(low_income)["puntaje"])
      .to be < described_class.new.fetch(high_income)["puntaje"]
  end
end

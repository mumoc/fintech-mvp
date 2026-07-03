require "rails_helper"

RSpec.describe Countries::CO::Normalizer do
  it "maps the CO payload to the internal BankData struct" do
    payload = { "deuda_bancaria" => 1_234_567.89, "puntaje" => 701, "estado_producto" => "vigente" }

    data = described_class.new.normalize(payload)

    expect(data).to be_a(Countries::BankData)
    expect(data.total_debt).to eq(1_234_567.89)
    expect(data.credit_score).to eq(701)
    expect(data.account_status).to eq("active")
  end

  it "maps 'en_mora' to 'delinquent'" do
    data = described_class.new.normalize({ "estado_producto" => "en_mora" })

    expect(data.account_status).to eq("delinquent")
  end

  it "falls back to 'unknown' for an unrecognized status" do
    data = described_class.new.normalize({ "estado_producto" => "??" })

    expect(data.account_status).to eq("unknown")
  end
end

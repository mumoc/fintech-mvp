require "rails_helper"

RSpec.describe Countries::MX::Normalizer do
  it "maps the MX payload to the internal BankData struct" do
    payload = { "deuda_total" => 12_345.67, "buro_score" => 712, "estatus_cuenta" => "activa" }

    data = described_class.new.normalize(payload)

    expect(data).to be_a(Countries::BankData)
    expect(data.total_debt).to eq(12_345.67)
    expect(data.credit_score).to eq(712)
    expect(data.account_status).to eq("active")
  end

  it "maps 'morosa' to 'delinquent'" do
    data = described_class.new.normalize({ "estatus_cuenta" => "morosa" })

    expect(data.account_status).to eq("delinquent")
  end

  it "falls back to 'unknown' for an unrecognized status" do
    data = described_class.new.normalize({ "estatus_cuenta" => "??" })

    expect(data.account_status).to eq("unknown")
  end
end

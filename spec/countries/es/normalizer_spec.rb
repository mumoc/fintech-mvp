require "rails_helper"

RSpec.describe Countries::ES::Normalizer do
  it "maps the ES payload shape to the internal BankData struct" do
    payload = { "total_liabilities" => 9_876.54, "scoring" => 812, "account_state" => "al_corriente" }

    data = described_class.new.normalize(payload)

    expect(data).to be_a(Countries::BankData)
    expect(data.total_debt).to eq(9_876.54)
    expect(data.credit_score).to eq(812)
    expect(data.account_status).to eq("active")
  end

  it "maps 'en_mora' to 'delinquent'" do
    data = described_class.new.normalize({ "account_state" => "en_mora" })

    expect(data.account_status).to eq("delinquent")
  end
end

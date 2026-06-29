require "rails_helper"

RSpec.describe BankRecord, type: :model do
  it "has a valid factory" do
    expect(build(:bank_record)).to be_valid
  end

  it { is_expected.to belong_to(:credit_application) }
  it { is_expected.to validate_presence_of(:provider) }

  it "retains the raw provider payload for audit" do
    record = create(:bank_record, raw_payload: { "any" => "shape" })

    expect(record.reload.raw_payload).to eq("any" => "shape")
  end
end

require "rails_helper"

RSpec.describe Countries::MX::Validator do
  # Well-formed CURP whose final digit (4) is the correct RENAPO check digit.
  VALID_CURP = "HEGG560427MVZRRL04".freeze

  def validator_for(document_number)
    applicant = Struct.new(:document_number).new(document_number)
    described_class.new(applicant)
  end

  it "accepts a valid CURP" do
    expect(validator_for(VALID_CURP)).to be_valid
  end

  it "accepts a lowercase CURP (normalized before checking)" do
    expect(validator_for(VALID_CURP.downcase)).to be_valid
  end

  it "rejects a malformed CURP with a clear error" do
    validator = validator_for("NOT-A-CURP")

    expect(validator).not_to be_valid
    expect(validator.errors).to include(a_string_matching(/CURP/))
  end

  it "rejects a CURP with a wrong check digit" do
    expect(validator_for("HEGG560427MVZRRL05")).not_to be_valid
  end

  it "rejects a CURP with an invalid birth month" do
    expect(validator_for("HEGG561327MVZRRL04")).not_to be_valid
  end
end

require "rails_helper"

RSpec.describe Countries::ES::Validator do
  def validator_for(document_number)
    described_class.new(Struct.new(:document_number).new(document_number))
  end

  it "accepts a valid DNI (correct mod-23 control letter)" do
    expect(validator_for("12345678Z")).to be_valid
    expect(validator_for("00000000T")).to be_valid
  end

  it "accepts a lowercase DNI (normalized)" do
    expect(validator_for("12345678z")).to be_valid
  end

  it "rejects a DNI with the wrong control letter" do
    validator = validator_for("12345678A")

    expect(validator).not_to be_valid
    expect(validator.errors).to include(a_string_matching(/DNI/))
  end

  it "rejects a malformed DNI" do
    expect(validator_for("1234567Z")).not_to be_valid
    expect(validator_for("ABCDEFGHZ")).not_to be_valid
  end
end

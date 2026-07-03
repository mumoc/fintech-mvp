require "rails_helper"

RSpec.describe Countries::CO::Validator do
  def validator_for(document_number)
    described_class.new(Struct.new(:document_number).new(document_number))
  end

  it "accepts a 10-digit string cedula" do
    expect(validator_for("1020304050")).to be_valid
  end

  it "rejects non-string documents" do
    validator = validator_for(1_020_304_050)

    expect(validator).not_to be_valid
    expect(validator.errors).to include(a_string_matching(/Cédula de Ciudadanía/))
  end

  it "rejects strings that are not exactly 10 digits" do
    expect(validator_for("123456789")).not_to be_valid
    expect(validator_for("12345678901")).not_to be_valid
    expect(validator_for("ABC1234567")).not_to be_valid
  end

  describe ".document_type" do
    it { expect(described_class.document_type("1020304050")).to eq("Cédula de Ciudadanía") }
  end
end

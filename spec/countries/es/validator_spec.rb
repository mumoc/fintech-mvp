require "rails_helper"

RSpec.describe Countries::ES::Validator do
  def validator_for(document_number)
    described_class.new(Struct.new(:document_number).new(document_number))
  end

  it "accepts a valid DNI (correct mod-23 control letter)" do
    expect(validator_for("12345678Z")).to be_valid
    expect(validator_for("00000000T")).to be_valid
  end

  it "accepts a valid NIE (foreigner ID; X/Y/Z prefix)" do
    expect(validator_for("Z8701355T")).to be_valid # Z->2, 28701355 % 23 -> T
    expect(validator_for("X0000000T")).to be_valid # X->0, 0 % 23 -> T
  end

  it "accepts a lowercase document (normalized)" do
    expect(validator_for("12345678z")).to be_valid
    expect(validator_for("z8701355t")).to be_valid
  end

  it "rejects a document with the wrong control letter" do
    validator = validator_for("12345678A")

    expect(validator).not_to be_valid
    expect(validator.errors).to include(a_string_matching(/DNI or NIE/))
  end

  it "rejects a NIE with the wrong control letter" do
    expect(validator_for("Z8701355A")).not_to be_valid
  end

  it "rejects a malformed document" do
    expect(validator_for("1234567Z")).not_to be_valid
    expect(validator_for("ABCDEFGHZ")).not_to be_valid
    expect(validator_for("W1234567T")).not_to be_valid # only X/Y/Z prefix the NIE
  end

  describe ".document_type" do
    it { expect(described_class.document_type("12345678Z")).to eq("DNI") }
    it { expect(described_class.document_type("Z8701355T")).to eq("NIE") }
  end
end

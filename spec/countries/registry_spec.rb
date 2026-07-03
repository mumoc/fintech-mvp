require "rails_helper"

RSpec.describe Countries::Registry do
  describe ".for" do
    it "returns the MX strategy bundle" do
      config = described_class.for("MX")

      expect(config.code).to eq("MX")
      expect(config.validator).to eq(Countries::MX::Validator)
      expect(config.bank_provider).to eq(Countries::MX::BankProvider)
      expect(config.normalizer).to eq(Countries::MX::Normalizer)
      expect(config.state_machine).to eq(Countries::MX::StateMachine)
    end

    it "returns the CO strategy bundle" do
      config = described_class.for("CO")

      expect(config.code).to eq("CO")
      expect(config.validator).to eq(Countries::CO::Validator)
      expect(config.bank_provider).to eq(Countries::CO::BankProvider)
      expect(config.normalizer).to eq(Countries::CO::Normalizer)
      expect(config.state_machine).to eq(Countries::CO::StateMachine)
    end

    it "raises for an unsupported country" do
      expect { described_class.for("XX") }
        .to raise_error(Countries::Registry::UnsupportedCountryError)
    end
  end

  describe ".supported?" do
    it { expect(described_class.supported?("MX")).to be(true) }
    it { expect(described_class.supported?("CO")).to be(true) }
    it { expect(described_class.supported?("ZZ")).to be(false) }
  end

  it "lists the supported codes" do
    expect(described_class.codes).to include("MX", "CO")
  end
end

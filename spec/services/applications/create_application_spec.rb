require "rails_helper"

RSpec.describe Applications::CreateApplication do
  let(:valid_curp) { "HEGG560427MVZRRL04" }

  def base_params(overrides = {})
    {
      country: "MX",
      full_name: "Juana Pérez",
      document_number: valid_curp,
      amount_requested: 100_000,
      monthly_income: 25_000
    }.merge(overrides)
  end

  describe "success" do
    it "persists the application with its initial state and a bank record" do
      result = nil
      expect { result = described_class.call!(params: base_params) }
        .to change(CreditApplication, :count).by(1)
        .and change(BankRecord, :count).by(1)

      expect(result).to be_success
      application = result.value
      expect(application.status).to eq("received")
      expect(application.flags).to eq({})
      expect(application.document_type).to eq("CURP")
    end

    it "normalizes the bank payload and keeps the raw response" do
      application = described_class.call!(params: base_params).value
      bank_record = application.bank_record

      expect(bank_record.provider).to eq("MX_PROVIDER")
      expect(bank_record.account_status).to be_in(%w[active delinquent unknown])
      expect(bank_record.raw_payload).to include("buro_score")
    end
  end

  describe "MX income ratio rule" do
    it "routes an over-leveraged application to review" do
      result = described_class.call!(
        params: base_params(amount_requested: 1_000_000, monthly_income: 25_000)
      )

      expect(result).to be_success
      expect(result.value.status).to eq("under_review")
      expect(result.value.flags).to include("requires_review" => true)
    end
  end

  describe "failures" do
    it "rejects an unsupported country without persisting" do
      result = nil
      expect { result = described_class.call!(params: base_params(country: "ZZ")) }
        .not_to change(CreditApplication, :count)

      expect(result).to be_failure
      expect(result.error.code).to eq(:unsupported_country)
    end

    it "rejects an invalid document without persisting" do
      result = nil
      expect { result = described_class.call!(params: base_params(document_number: "NOT-A-CURP")) }
        .not_to change(CreditApplication, :count)

      expect(result).to be_failure
      expect(result.error.code).to eq(:invalid_document)
    end

    it "rejects a duplicate document" do
      described_class.call!(params: base_params)

      result = nil
      expect { result = described_class.call!(params: base_params) }
        .not_to change(CreditApplication, :count)

      expect(result).to be_failure
    end
  end
end

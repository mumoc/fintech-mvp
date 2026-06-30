require "rails_helper"

RSpec.describe CreditApplication, type: :model do
  it "has a valid factory" do
    expect(build(:credit_application)).to be_valid
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:country) }
    it { is_expected.to validate_presence_of(:document_type) }
    it { is_expected.to validate_presence_of(:document_number) }
    it { is_expected.to validate_presence_of(:full_name) }

    it "requires a positive amount_requested" do
      expect(build(:credit_application, amount_requested: 0)).not_to be_valid
    end

    it "requires a positive monthly_income" do
      expect(build(:credit_application, monthly_income: 0)).not_to be_valid
    end
  end

  describe "associations" do
    it { is_expected.to have_one(:bank_record).dependent(:destroy) }
    it { is_expected.to have_many(:state_transitions).dependent(:destroy) }
    it { is_expected.to have_many(:webhook_deliveries).dependent(:destroy) }
  end

  describe "PII encryption at rest" do
    let(:application) do
      create(
        :credit_application,
        full_name: "Top Secret Name",
        document_number: "SECRETDOC777",
        monthly_income: 98_765.43
      )
    end

    def raw_column(name)
      ActiveRecord::Base.connection.select_value(
        ActiveRecord::Base.sanitize_sql_array(
          [ "SELECT #{name} FROM credit_applications WHERE id = ?", application.id ]
        )
      )
    end

    it "stores full_name as ciphertext" do
      expect(raw_column("full_name")).not_to include("Top Secret Name")
      expect(application.reload.full_name).to eq("Top Secret Name")
    end

    it "stores document_number as ciphertext" do
      expect(raw_column("document_number")).not_to include("SECRETDOC777")
      expect(application.reload.document_number).to eq("SECRETDOC777")
    end

    it "stores monthly_income as ciphertext" do
      expect(raw_column("monthly_income")).not_to include("98765")
      expect(application.reload.monthly_income).to eq(98_765.43)
    end
  end

  describe "deterministic document_number" do
    it "is searchable by exact value" do
      application = create(:credit_application, document_number: "FINDME123")

      expect(CreditApplication.find_by(document_number: "FINDME123")).to eq(application)
    end
  end

  describe "document_fingerprint blind index" do
    it "is generated from the document number" do
      application = create(:credit_application, document_number: "ABCDEF0001")

      expect(application.document_fingerprint).to eq(
        described_class.fingerprint_for("ABCDEF0001")
      )
      expect(application.document_fingerprint).not_to include("ABCDEF0001")
    end

    it "rejects a duplicate document (normalized) via fingerprint uniqueness" do
      create(:credit_application, document_number: "Dup-Doc-9")
      duplicate = build(:credit_application, document_number: "dup-doc-9")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:document_fingerprint]).to be_present
    end

    it "enforces uniqueness at the database level" do
      create(:credit_application, document_number: "RACE-1")
      duplicate = build(:credit_application, document_number: "RACE-1")
      duplicate.document_fingerprint = described_class.fingerprint_for("RACE-1")

      expect { duplicate.save!(validate: false) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end

require "rails_helper"

RSpec.describe CreditApplicationSerializer do
  let(:application) do
    create(
      :credit_application,
      full_name: "Top Secret Name",
      document_number: "SECRETDOC42",
      monthly_income: 42_000.50
    )
  end

  def serialize(role)
    described_class.new(application, user: build(:user, role: role)).as_json
  end

  it "always exposes non-PII attributes" do
    json = serialize(:operator)

    expect(json).to include(
      id: application.id,
      country: application.country,
      amount_requested: application.amount_requested,
      status: application.status
    )
  end

  describe "operator (unauthorized for PII)" do
    it "omits document_number and monthly_income" do
      json = serialize(:operator)

      expect(json).not_to have_key(:document_number)
      expect(json).not_to have_key(:monthly_income)
      expect(json).not_to have_key(:full_name)
    end
  end

  describe "analyst (authorized for PII)" do
    it "includes the decrypted PII" do
      json = serialize(:analyst)

      expect(json).to include(
        full_name: "Top Secret Name",
        document_number: "SECRETDOC42",
        monthly_income: 42_000.50
      )
    end
  end

  describe "admin (authorized for PII)" do
    it "includes the PII" do
      expect(serialize(:admin)).to have_key(:document_number)
    end
  end
end

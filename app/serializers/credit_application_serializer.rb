# Scope-aware serializer: PII fields are included only when the requesting user
# is authorized to see them (analyst/admin). Operators receive a redacted view.
class CreditApplicationSerializer
  PII_ATTRIBUTES = %i[full_name document_number monthly_income].freeze

  def initialize(application, user:)
    @application = application
    @user = user
  end

  def as_json(*)
    base = public_attributes
    base.merge!(pii_attributes) if view_pii?
    base
  end

  private

  attr_reader :application, :user

  def public_attributes
    {
      id: application.id,
      country: application.country,
      document_type: application.document_type,
      amount_requested: application.amount_requested,
      status: application.status,
      risk_score: application.risk_score,
      flags: application.flags,
      requested_at: application.requested_at,
      created_at: application.created_at,
      updated_at: application.updated_at
    }
  end

  def pii_attributes
    {
      full_name: application.full_name,
      document_number: application.document_number,
      monthly_income: application.monthly_income
    }
  end

  def view_pii?
    CreditApplicationPolicy.new(user, application).view_pii?
  end
end

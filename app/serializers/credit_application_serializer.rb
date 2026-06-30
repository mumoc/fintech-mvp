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

  # Non-PII view, safe to broadcast to every subscriber regardless of role.
  def self.redacted(application)
    new(application, user: nil).public_attributes
  end

  # Public, non-PII attributes (always present in the serialized output).
  def public_attributes
    {
      id: application.id,
      country: application.country,
      document_type: application.document_type,
      amount_requested: application.amount_requested,
      status: application.status,
      risk_score: application.risk_score,
      flags: application.flags,
      lock_version: application.lock_version,
      requested_at: application.requested_at,
      created_at: application.created_at,
      updated_at: application.updated_at,
      bank_record: bank_record_summary
    }
  end

  private

  attr_reader :application, :user

  # Normalized bank summary (not PII). nil until bank data has been fetched.
  def bank_record_summary
    record = application.bank_record
    return nil unless record

    {
      provider: record.provider,
      total_debt: record.total_debt,
      credit_score: record.credit_score,
      account_status: record.account_status
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

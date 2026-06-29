# Role matrix:
#   operator → create + read
#   analyst  → create + read + change status
#   admin    → everything
# PII (full_name / document_number / monthly_income) is only visible to
# analyst and admin; operators get a redacted view (see the serializer).
class CreditApplicationPolicy < ApplicationPolicy
  def index? = true
  def show? = true
  def create? = true

  def update_status? = analyst_or_admin?

  # Drives the scope-aware serializer.
  def view_pii? = analyst_or_admin?

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.all
  end

  private

  def analyst_or_admin?
    user.analyst? || user.admin?
  end
end

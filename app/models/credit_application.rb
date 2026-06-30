class CreditApplication < ApplicationRecord
  has_one :bank_record, dependent: :destroy
  has_many :state_transitions, dependent: :destroy
  has_many :webhook_deliveries, dependent: :destroy

  # PII at rest. document_number is deterministic so it can be searched / deduped
  # by exact match; full_name and monthly_income never need search → stronger,
  # non-deterministic encryption.
  encrypts :full_name
  encrypts :document_number, deterministic: true
  attribute :monthly_income, :decimal
  encrypts :monthly_income

  before_validation :assign_document_fingerprint

  validates :country, presence: true
  validates :document_type, presence: true
  validates :document_number, presence: true
  validates :full_name, presence: true
  validates :amount_requested, presence: true, numericality: { greater_than: 0 }
  validates :monthly_income, presence: true, numericality: { greater_than: 0 }
  validates :document_fingerprint, presence: true, uniqueness: true

  # Keyed HMAC of the (normalized) document number. Stored in clear so it can be
  # uniquely indexed for dedupe without exposing the document itself.
  def self.fingerprint_for(document_number)
    return if document_number.blank?

    normalized = document_number.to_s.strip.upcase
    key = Rails.application.config.x.blind_index_key
    OpenSSL::HMAC.hexdigest("SHA256", key, normalized)
  end

  private

  def assign_document_fingerprint
    self.document_fingerprint = self.class.fingerprint_for(document_number)
  end
end

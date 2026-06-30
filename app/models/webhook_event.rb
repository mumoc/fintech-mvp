class WebhookEvent < ApplicationRecord
  validates :idempotency_key, presence: true, uniqueness: true
  validates :source, presence: true
end

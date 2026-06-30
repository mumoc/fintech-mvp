class OutboxEvent < ApplicationRecord
  scope :pending, -> { where(processed_at: nil) }
end

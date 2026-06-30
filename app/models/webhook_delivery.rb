class WebhookDelivery < ApplicationRecord
  belongs_to :credit_application

  validates :endpoint, :status, presence: true
end

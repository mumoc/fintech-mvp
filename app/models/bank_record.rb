class BankRecord < ApplicationRecord
  belongs_to :credit_application

  validates :provider, presence: true
end

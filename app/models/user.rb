class User < ApplicationRecord
  has_secure_password

  enum :role, { operator: 0, analyst: 1, admin: 2 }

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :role, presence: true
end

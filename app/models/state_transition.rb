class StateTransition < ApplicationRecord
  belongs_to :credit_application
  belongs_to :actor, class_name: "User", optional: true

  validates :to_state, presence: true
end

FactoryBot.define do
  factory :state_transition do
    credit_application
    from_state { "received" }
    to_state { "under_review" }
    reason { "manual review" }
    metadata { {} }
  end
end

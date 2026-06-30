module Countries
  module ES
    # ES status machine. Inherits the shared transition graph from
    # Base::StateMachine; supplies the ES intake rule: an application above the
    # review threshold is routed to manual review.
    class StateMachine < Base::StateMachine
      INITIAL_STATE = "received".freeze
      REVIEW_THRESHOLD = 50_000 # EUR

      def intake
        if application.amount_requested.to_d > REVIEW_THRESHOLD
          Countries::IntakeDecision.new(
            status: "under_review",
            flags: { "requires_review" => true, "reason" => "amount_exceeds_review_threshold" }
          )
        else
          Countries::IntakeDecision.new(status: INITIAL_STATE, flags: {})
        end
      end
    end
  end
end

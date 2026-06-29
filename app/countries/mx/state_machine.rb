module Countries
  module MX
    # MX status policy. Intake rule: an application whose requested amount exceeds
    # RATIO_LIMIT times the monthly income is routed to manual review.
    # The AASM transition graph lands in T009.
    class StateMachine < Base::StateMachine
      INITIAL_STATE = "received".freeze
      RATIO_LIMIT = 30 # amount_requested must be <= monthly_income * 30

      def intake(application)
        if ratio_exceeded?(application)
          Countries::IntakeDecision.new(
            status: "under_review",
            flags: { "requires_review" => true, "reason" => "amount_to_income_ratio_exceeded" }
          )
        else
          Countries::IntakeDecision.new(status: INITIAL_STATE, flags: {})
        end
      end

      private

      def ratio_exceeded?(application)
        income = application.monthly_income.to_d
        return false if income.zero?

        application.amount_requested.to_d > income * RATIO_LIMIT
      end
    end
  end
end

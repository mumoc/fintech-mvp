module Countries
  module Base
    # A country's status policy. Decides the initial status + flags for a new
    # application (intake). The AASM transition graph for status changes lands in
    # T009; this anchors the intake decision used at creation time.
    class StateMachine
      # @param application [CreditApplication]
      # @return [Countries::IntakeDecision]
      def intake(_application)
        raise NotImplementedError, "#{self.class} must implement #intake"
      end
    end
  end
end

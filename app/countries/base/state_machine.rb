module Countries
  module Base
    # A country's status state machine. The transition graph is shared domain
    # logic (AASM); a country wraps it and supplies the country-specific intake
    # decision. AASM operates on the wrapped application's `status` column, so
    # firing an event mutates the application in memory; the caller persists it
    # (with optimistic locking) and records the transition.
    class StateMachine
      include AASM

      def initialize(application)
        @application = application
      end

      aasm column: :status, whiny_transitions: true do
        state :received, initial: true
        state :under_review
        state :approved
        state :rejected
        state :cancelled

        event :start_review do
          transitions from: %i[received], to: :under_review
        end

        event :approve do
          transitions from: %i[received under_review], to: :approved
        end

        event :reject do
          transitions from: %i[received under_review], to: :rejected
        end

        event :cancel do
          transitions from: %i[received under_review], to: :cancelled
        end
      end

      # Initial status + flags for a brand-new application — country-specific.
      # @return [Countries::IntakeDecision]
      def intake
        raise NotImplementedError, "#{self.class} must implement #intake"
      end

      # --- AASM persistence hooks: read/write state on the wrapped application ---
      # (AASM tracks state internally for plain objects; these make the wrapped
      #  application's `status` column the single source of truth instead.)

      def aasm_read_state(_name = :default)
        application.status.presence&.to_sym || :received
      end

      def aasm_write_state(new_state, _name = :default)
        application.status = new_state.to_s
        true
      end
      alias aasm_write_state_without_persistence aasm_write_state

      private

      attr_reader :application
    end
  end
end

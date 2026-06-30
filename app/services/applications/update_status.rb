module Applications
  # Transitions an application's status through its country state machine,
  # records the transition, and persists under optimistic locking.
  # Returns a Result:
  #   :invalid_transition (guard / unknown event) — state left unchanged
  #   :conflict           (stale lock_version)
  class UpdateStatus
    def self.call!(application:, event:, actor: nil, reason: nil, expected_lock_version: nil)
      new(
        application: application, event: event, actor: actor,
        reason: reason, expected_lock_version: expected_lock_version
      ).call!
    end

    def initialize(application:, event:, actor: nil, reason: nil, expected_lock_version: nil)
      @application = application
      @event = event.to_s
      @actor = actor
      @reason = reason
      @expected_lock_version = expected_lock_version
    end

    def call!
      machine = Countries::Registry.for(@application.country).state_machine.new(@application)

      unless transition_allowed?(machine)
        return Result.failure(:invalid_transition, "Cannot '#{@event}' from '#{@application.status}'")
      end

      from_state = @application.status
      machine.public_send("#{@event}!") # mutates @application.status in memory
      apply_expected_lock_version

      persist!(from_state)
      Result.success(@application)
    rescue ActiveRecord::StaleObjectError
      Result.failure(:conflict, "The application was modified by someone else; reload and retry")
    end

    private

    def transition_allowed?(machine)
      machine.aasm.events.map(&:name).include?(@event.to_sym) &&
        machine.public_send("may_#{@event}?")
    end

    def apply_expected_lock_version
      return if @expected_lock_version.nil?

      @application.lock_version = Integer(@expected_lock_version)
    rescue ArgumentError, TypeError
      # Non-integer lock_version: ignore and fall back to the loaded version.
    end

    def persist!(from_state)
      ApplicationRecord.transaction do
        @application.save!
        @application.state_transitions.create!(
          from_state: from_state,
          to_state: @application.status,
          actor: @actor,
          reason: @reason
        )
      end
    end
  end
end

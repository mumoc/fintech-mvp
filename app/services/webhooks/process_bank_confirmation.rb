module Webhooks
  # Inbound bank confirmation. Dedupes by idempotency_key (unique), so a replayed
  # webhook is recorded once and mutates the application exactly once. The record,
  # mutation, and processed mark are one transaction.
  class ProcessBankConfirmation
    def self.call!(idempotency_key:, source:, payload:)
      new(idempotency_key: idempotency_key, source: source, payload: payload).call!
    end

    def initialize(idempotency_key:, source:, payload:)
      @idempotency_key = idempotency_key
      @source = source
      @payload = payload
    end

    def call!
      return Result.failure(:invalid_payload, "idempotency_key is required") if @idempotency_key.blank?

      existing = WebhookEvent.find_by(idempotency_key: @idempotency_key)
      return Result.success(existing) if existing # replay — idempotent no-op

      event = nil
      ApplicationRecord.transaction do
        event = WebhookEvent.create!(idempotency_key: @idempotency_key, source: @source, payload: @payload)
        @application = apply!(event)
        event.update!(processed_at: Time.current)
      end

      # Broadcast AFTER commit so subscribers never see a rolled-back change. The
      # open UI updates in realtime when the bank confirms (no refresh).
      broadcast_confirmation
      Result.success(event)
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
      # Concurrent duplicate: if the key now exists it was a race; otherwise the
      # error is real (e.g. the application update failed) and must surface.
      duplicate = WebhookEvent.find_by(idempotency_key: @idempotency_key)
      raise e unless duplicate

      Result.success(duplicate)
    end

    private

    def apply!(event)
      application = CreditApplication.find_by(id: event.payload["application_id"])
      return if application.nil?

      application.update!(flags: application.flags.merge("bank_confirmed" => true))
      application
    end

    def broadcast_confirmation
      return if @application.nil?

      Applications::Broadcaster.application_changed(@application, event: "bank_confirmed")
    end
  end
end

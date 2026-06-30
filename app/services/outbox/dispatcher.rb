module Outbox
  # Drains the transactional outbox. Pending events are claimed with
  # `FOR UPDATE SKIP LOCKED`, so N dispatchers can run in parallel without two
  # ever claiming the same row — each skips rows locked by the others. Enqueue
  # happens inside the same transaction that marks the rows processed, giving
  # at-least-once delivery (downstream jobs are idempotent).
  class Dispatcher
    DEFAULT_BATCH_SIZE = 100

    def initialize(batch_size: DEFAULT_BATCH_SIZE)
      @batch_size = batch_size
    end

    # Claims and processes one batch. Returns the claimed event ids.
    def claim_batch
      claimed_ids = []

      OutboxEvent.transaction do
        events = OutboxEvent.pending
                            .order(:created_at)
                            .lock("FOR UPDATE SKIP LOCKED")
                            .limit(@batch_size)
                            .to_a
        events.each { |event| Router.dispatch(event) }

        claimed_ids = events.map(&:id)
        OutboxEvent.where(id: claimed_ids).update_all(processed_at: Time.current) if claimed_ids.any?
      end

      claimed_ids
    end

    # Processes all currently-pending events (used by the recurring job).
    def drain
      total = 0
      loop do
        claimed = claim_batch.size
        total += claimed
        break if claimed.zero?
      end
      total
    end
  end
end

require "rails_helper"

# Real parallel dispatchers need committed data visible across connections, so
# transactional fixtures are disabled here and rows are cleaned up manually.
RSpec.describe "Outbox::Dispatcher concurrency", type: :model do
  self.use_transactional_tests = false

  after { OutboxEvent.delete_all }

  it "never lets two parallel dispatchers claim the same event (SKIP LOCKED)" do
    ids = Array.new(60) do
      OutboxEvent.create!(
        aggregate_type: "CreditApplication",
        aggregate_id: SecureRandom.uuid,
        event_type: "noop", # routed to no jobs — isolates the claim logic
        payload: {}
      ).id
    end

    mutex = Mutex.new
    claimed = []

    threads = Array.new(2) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          dispatcher = Outbox::Dispatcher.new(batch_size: 5)
          loop do
            batch = dispatcher.claim_batch
            break if batch.empty?

            mutex.synchronize { claimed.concat(batch) }
          end
        end
      end
    end
    threads.each(&:join)

    expect(claimed.sort).to eq(ids.sort)               # every event claimed
    expect(claimed.uniq.length).to eq(claimed.length)  # none claimed twice
    expect(OutboxEvent.pending.count).to eq(0)         # all marked processed
  end
end

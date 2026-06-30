# Recurring job (see config/sidekiq_cron.yml) that drains the outbox. Safe to run
# as multiple replicas — Outbox::Dispatcher uses FOR UPDATE SKIP LOCKED.
class OutboxDispatchJob
  include Sidekiq::Job
  sidekiq_options queue: "default", retry: 5

  def perform
    Outbox::Dispatcher.new.drain
  end
end

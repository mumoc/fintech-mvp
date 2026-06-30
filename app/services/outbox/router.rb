module Outbox
  # Maps an outbox event type to the downstream Sidekiq job(s) it should enqueue.
  # Job names are resolved lazily (constantize) so new consumers can be added
  # without load-order coupling. Downstream jobs receive the aggregate id and are
  # idempotent.
  class Router
    ROUTES = {
      "created" => %w[RiskEvaluationJob],
      "status_changed" => %w[RiskEvaluationJob WebhookDeliveryJob]
    }.freeze

    def self.dispatch(event)
      job_names(event).each do |name|
        name.constantize.perform_async(event.aggregate_id)
      end
    end

    def self.job_names(event)
      ROUTES.fetch(event.event_type, [])
    end
  end
end

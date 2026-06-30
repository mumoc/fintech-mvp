# Enqueued by the outbox dispatcher for created / status_changed events.
# The idempotent risk-scoring logic and structured logging are implemented in
# T012; for now this is the dispatch target.
class RiskEvaluationJob
  include Sidekiq::Job
  sidekiq_options queue: "default", retry: 5

  def perform(application_id)
    # Implemented in T012.
  end
end

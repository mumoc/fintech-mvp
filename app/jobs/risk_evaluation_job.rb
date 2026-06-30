# Computes a risk score for an application. Enqueued by the outbox dispatcher.
# Idempotent: it only writes risk_score when it is still null, using a
# conditional UPDATE so concurrent runs (or retries) produce a single effect.
class RiskEvaluationJob
  include Sidekiq::Job
  sidekiq_options queue: "default", retry: 5

  def perform(application_id)
    application = CreditApplication.find_by(id: application_id)
    return logger.info(event: "risk_evaluation.application_missing", application_id: application_id) if application.nil?

    if application.risk_score.present?
      return logger.info(event: "risk_evaluation.skipped", application_id: application.id, country: application.country)
    end

    score = calculate_score(application)

    # Conditional write: only the first runner (risk_score still null) wins.
    affected = CreditApplication.where(id: application.id, risk_score: nil)
                                .update_all(risk_score: score, updated_at: Time.current)

    if affected.zero?
      logger.info(event: "risk_evaluation.skipped", application_id: application.id, country: application.country)
    else
      logger.info(
        event: "risk_evaluation.completed",
        application_id: application.id,
        country: application.country,
        risk_score: score
      )
    end
  end

  private

  def logger
    @logger ||= StructuredLogger.new
  end

  # Deterministic heuristic: higher bureau score lowers risk, higher leverage
  # (amount / income) raises it. Range 0..100.
  def calculate_score(application)
    credit_score = application.bank_record&.credit_score || 600
    income = [ application.monthly_income.to_i, 1 ].max
    leverage = application.amount_requested.to_i / income

    credit_component = (850 - credit_score).clamp(0, 550) * 100 / 550
    (credit_component + leverage).clamp(0, 100)
  end
end

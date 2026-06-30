# Emits one JSON log line per event with the mandatory keys event / country /
# application_id. PII keys are stripped defensively, so callers can never leak
# document_number / monthly_income / full_name through the extra payload.
class StructuredLogger
  PII_KEYS = %w[document_number monthly_income full_name].freeze

  def initialize(logger = Rails.logger)
    @logger = logger
  end

  def info(event:, application_id: nil, country: nil, **extra)
    emit(:info, event, application_id, country, extra)
  end

  def error(event:, application_id: nil, country: nil, **extra)
    emit(:error, event, application_id, country, extra)
  end

  private

  def emit(level, event, application_id, country, extra)
    payload = { event: event, country: country, application_id: application_id }
              .merge(sanitize(extra))
              .compact
    @logger.public_send(level, payload.to_json)
  end

  def sanitize(extra)
    extra.reject { |key, _| PII_KEYS.include?(key.to_s) }
  end
end

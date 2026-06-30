# Outbound webhook: notifies a simulated external endpoint of a state change.
# Enqueued by the outbox dispatcher (status_changed). HMAC-signed; records each
# attempt in webhook_deliveries; raises on failure so Sidekiq retries.
class WebhookDeliveryJob
  include Sidekiq::Job
  sidekiq_options queue: "default", retry: 5

  DeliveryError = Class.new(StandardError)

  def perform(application_id)
    application = CreditApplication.find_by(id: application_id)
    return if application.nil?

    body = payload_for(application).to_json
    delivery = WebhookDelivery.create!(
      credit_application: application, endpoint: endpoint, status: "pending", attempts: 0
    )

    response = deliver(body)
    finalize(delivery, application, response)
  rescue DeliveryError
    raise # already recorded; let Sidekiq retry
  rescue StandardError => e
    mark_failed(delivery, error: e.message) if delivery
    log(:error, "webhook.delivery_failed", application)
    raise # network/unexpected error -> retry
  end

  private

  def deliver(body)
    Webhooks::Client.post(endpoint, body, signed_headers(body))
  end

  def finalize(delivery, application, response)
    if response.success?
      delivery.update!(status: "delivered", attempts: delivery.attempts + 1,
                       last_response: { "code" => response.code })
      log(:info, "webhook.delivered", application)
    else
      mark_failed(delivery, code: response.code)
      log(:error, "webhook.delivery_failed", application, code: response.code)
      raise DeliveryError, "HTTP #{response.code}"
    end
  end

  def mark_failed(delivery, code: nil, error: nil)
    delivery.update!(status: "failed", attempts: delivery.attempts + 1,
                     last_response: { "code" => code, "error" => error }.compact)
  end

  def payload_for(application)
    { event: "status_changed", application_id: application.id, status: application.status, country: application.country }
  end

  def signed_headers(body)
    { "Content-Type" => "application/json", "X-Webhook-Signature" => WebhookSignature.sign(body) }
  end

  def endpoint
    ENV.fetch("WEBHOOK_ENDPOINT_URL", "https://example.com/webhooks/credit-applications")
  end

  def log(level, event, application, **extra)
    @logger ||= StructuredLogger.new
    @logger.public_send(level, event: event, application_id: application&.id, country: application&.country, **extra)
  end
end

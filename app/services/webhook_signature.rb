# HMAC-SHA256 signing/verification shared by outbound and inbound webhooks.
# The secret comes from the environment (non-secret dev default in .env.example).
class WebhookSignature
  def self.secret
    ENV.fetch("WEBHOOK_SIGNING_SECRET", "dev_only_webhook_secret_replace_in_production")
  end

  def self.sign(body)
    OpenSSL::HMAC.hexdigest("SHA256", secret, body.to_s)
  end

  def self.valid?(body, signature)
    return false if signature.blank?

    ActiveSupport::SecurityUtils.secure_compare(sign(body), signature)
  end
end

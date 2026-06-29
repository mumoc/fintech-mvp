# Stateless JWT encode/decode for API authentication.
# Tokens are signed with HS256 using a dedicated secret (falls back to the
# Rails secret_key_base in development). `decode` returns nil for any invalid
# token (bad signature, malformed, or expired) so callers treat all failures
# uniformly as "unauthenticated".
class JsonWebToken
  ALGORITHM = "HS256".freeze
  DEFAULT_EXPIRY = 24.hours

  class << self
    def encode(payload, exp: DEFAULT_EXPIRY.from_now)
      payload = payload.dup
      payload[:exp] = exp.to_i
      JWT.encode(payload, secret, ALGORITHM)
    end

    def decode(token)
      decoded, = JWT.decode(token, secret, true, algorithm: ALGORITHM)
      decoded.with_indifferent_access
    rescue JWT::DecodeError
      nil
    end

    private

    def secret
      ENV.fetch("JWT_SECRET") { Rails.application.secret_key_base }
    end
  end
end

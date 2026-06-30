module Applications
  # Caches the serialized view of a single application. The key includes
  # `cache_key_with_version` (id + updated_at), so any write changes the key and
  # the stale entry is never served — no manual busting. The PII scope is part of
  # the key so an operator's redacted view is never served to an analyst.
  class CachedView
    def self.fetch(application, user:)
      Rails.cache.fetch(cache_key(application, user)) do
        CreditApplicationSerializer.new(application, user: user).as_json
      end
    end

    def self.cache_key(application, user)
      [ "credit_application", application.cache_key_with_version, pii_scope(user) ]
    end

    def self.pii_scope(user)
      CreditApplicationPolicy.new(user, application_class).view_pii? ? "pii" : "redacted"
    end

    def self.application_class
      CreditApplication
    end
  end
end

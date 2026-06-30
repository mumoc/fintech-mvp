module Countries
  # Serializable catalog of supported countries (code + document type), cached
  # with a long TTL — it only changes when a country is added/deployed. Consumed
  # by the API (and the frontend's create form).
  class Catalog
    CACHE_KEY_PREFIX = "countries:catalog".freeze
    TTL = 12.hours

    def self.all
      Rails.cache.fetch(cache_key, expires_in: TTL) { build }
    end

    # Key includes the supported set, so adding a country changes the key and the
    # catalog refreshes on the next deploy — no stale list, no manual busting.
    def self.cache_key
      "#{CACHE_KEY_PREFIX}:#{Registry.codes.sort.join('-')}"
    end

    def self.build
      Registry.codes.map do |code|
        { "code" => code, "document_type" => Registry.for(code).validator::DOCUMENT_TYPE }
      end
    end
  end
end

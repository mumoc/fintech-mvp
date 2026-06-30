module Countries
  # Serializable catalog of supported countries (code + document type), cached
  # with a long TTL — it only changes when a country is added/deployed. Consumed
  # by the API (and the frontend's create form).
  class Catalog
    CACHE_KEY = "countries:catalog".freeze
    TTL = 12.hours

    def self.all
      Rails.cache.fetch(CACHE_KEY, expires_in: TTL) { build }
    end

    def self.build
      Registry.codes.map do |code|
        { "code" => code, "document_type" => Registry.for(code).validator::DOCUMENT_TYPE }
      end
    end
  end
end

module Countries
  # Resolves a country code to its sealed strategy bundle. Adding a country means
  # adding `app/countries/<code>/` (the four strategy classes) plus ONE line in
  # NAMESPACES below — nothing in controllers, services, jobs, or models.
  class Registry
    UnsupportedCountryError = Class.new(StandardError)

    # One line per supported country — the architectural signature.
    NAMESPACES = {
      "MX" => MX,
      "ES" => ES,
      "CO" => CO
    }.freeze

    class << self
      def for(code)
        configs.fetch(code) do
          raise UnsupportedCountryError, "Unsupported country: #{code.inspect}"
        end
      end

      def supported?(code)
        configs.key?(code)
      end

      def codes
        configs.keys
      end

      private

      def configs
        @configs ||= NAMESPACES.to_h do |code, namespace|
          [ code, Country.for_namespace(code, namespace) ]
        end
      end
    end
  end
end

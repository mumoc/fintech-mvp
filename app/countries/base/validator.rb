module Countries
  module Base
    # Validates that an application's document is acceptable for the country.
    # Subclasses implement #errors (empty array == valid).
    class Validator
      # The document type for a given value. Defaults to the country's single
      # type; countries with several (e.g. ES: DNI/NIE) override this.
      def self.document_type(_document_number)
        self::DOCUMENT_TYPE
      end

      def initialize(application)
        @application = application
      end

      # @return [Array<String>] human-readable validation errors.
      def errors
        raise NotImplementedError, "#{self.class} must implement #errors"
      end

      def valid?
        errors.empty?
      end

      private

      attr_reader :application
    end
  end
end

module Countries
  module Base
    # Validates that an application's document is acceptable for the country.
    # Subclasses implement #errors (empty array == valid).
    class Validator
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

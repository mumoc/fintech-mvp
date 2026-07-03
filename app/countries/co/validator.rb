module Countries
  module CO
    # Validates a Colombian Cedula de Ciudadania for this MVP: exactly 10 digits,
    # provided as a string so leading zeros are preserved if present.
    class Validator < Base::Validator
      DOCUMENT_TYPE = "Cédula de Ciudadanía".freeze
      CEDULA_REGEX = /\A\d{10}\z/

      def errors
        errs = []
        errs << "document_number must be a valid Cédula de Ciudadanía" unless valid_cedula?
        errs
      end

      private

      def valid_cedula?
        application.document_number.is_a?(String) && CEDULA_REGEX.match?(application.document_number.strip)
      end
    end
  end
end

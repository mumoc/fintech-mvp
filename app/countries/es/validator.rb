module Countries
  module ES
    # Validates a Spanish DNI: 8 digits + a control letter derived from the
    # number modulo 23 (the letter is deterministic over the digits).
    class Validator < Base::Validator
      DOCUMENT_TYPE = "DNI".freeze
      CONTROL_LETTERS = "TRWAGMYFPDXBNJZSQVHLCKE".freeze
      DNI_REGEX = /\A\d{8}[A-Z]\z/

      def errors
        errs = []
        errs << "document_number must be a valid DNI" unless valid_dni?
        errs
      end

      private

      def valid_dni?
        dni = application.document_number.to_s.strip.upcase
        return false unless DNI_REGEX.match?(dni)

        number = dni[0, 8].to_i
        dni[8] == CONTROL_LETTERS[number % 23]
      end
    end
  end
end

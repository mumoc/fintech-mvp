module Countries
  module ES
    # Validates a Spanish identity document — DNI (citizens) or NIE (foreigners).
    # Both use the same mod-23 control letter; a NIE replaces its leading letter
    # (X→0, Y→1, Z→2) to form the number first.
    class Validator < Base::Validator
      DOCUMENT_TYPE = "DNI".freeze
      CONTROL_LETTERS = "TRWAGMYFPDXBNJZSQVHLCKE".freeze

      DNI_REGEX = /\A\d{8}[A-Z]\z/
      NIE_REGEX = /\A[XYZ]\d{7}[A-Z]\z/
      NIE_PREFIX = { "X" => "0", "Y" => "1", "Z" => "2" }.freeze

      def self.document_type(document_number)
        NIE_REGEX.match?(normalize(document_number)) ? "NIE" : "DNI"
      end

      def self.normalize(document_number)
        document_number.to_s.strip.upcase
      end

      def errors
        errs = []
        errs << "document_number must be a valid DNI or NIE" unless valid_document?
        errs
      end

      private

      def valid_document?
        document = self.class.normalize(application.document_number)
        return false unless DNI_REGEX.match?(document) || NIE_REGEX.match?(document)

        document[-1] == CONTROL_LETTERS[numeric_part(document) % 23]
      end

      def numeric_part(document)
        if NIE_REGEX.match?(document)
          (NIE_PREFIX.fetch(document[0]) + document[1, 7]).to_i
        else
          document[0, 8].to_i
        end
      end
    end
  end
end

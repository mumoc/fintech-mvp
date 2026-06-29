module Countries
  module MX
    # Validates a Mexican CURP: 18-character format plus the RENAPO check-digit
    # algorithm (the last digit is deterministic over the first 17 characters).
    class Validator < Base::Validator
      # 4 letters, YYMMDD, sex, 2-letter state, 3 consonants, homoclave, check digit.
      STATE_CODES = %w[
        AS BC BS CC CL CM CS CH DF DG GT GR HG JC MC MN MS NT NL OC PL QT QR
        SP SL SR TC TS TL VZ YN ZS NE
      ].freeze

      CURP_REGEX = /
        \A
        [A-Z][AEIOUX][A-Z]{2}          # name initials
        \d{2}(?:0[1-9]|1[0-2])(?:0[1-9]|[12]\d|3[01]) # birth date YYMMDD
        [HM]                            # sex
        (?:#{STATE_CODES.join('|')})    # state of birth
        [B-DF-HJ-NP-TV-Z]{3}            # internal consonants
        [A-Z\d]                         # homoclave
        \d                              # check digit
        \z
      /x

      # RENAPO value dictionary; the index of a character is its weight.
      DICTIONARY = "0123456789ABCDEFGHIJKLMNÑOPQRSTUVWXYZ".freeze

      def errors
        errs = []
        errs << "document_number must be a valid CURP" unless valid_curp?
        errs
      end

      private

      def valid_curp?
        curp = application.document_number.to_s.strip.upcase
        return false unless CURP_REGEX.match?(curp)

        curp[17] == expected_check_digit(curp[0, 17]).to_s
      end

      def expected_check_digit(first_seventeen)
        sum = first_seventeen.chars.each_with_index.sum do |char, index|
          DICTIONARY.index(char).to_i * (18 - index)
        end
        (10 - (sum % 10)) % 10
      end
    end
  end
end

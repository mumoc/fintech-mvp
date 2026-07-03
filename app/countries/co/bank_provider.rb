require "digest"

module Countries
  module CO
    # Simulated Colombian bank provider. Returns a CO-specific payload shape and
    # derives the score from debt relative to income, while staying deterministic
    # from the document number for stable tests.
    class BankProvider < Base::BankProvider
      PROVIDER = "CO_PROVIDER".freeze

      def fetch(application)
        seed = Digest::SHA256.hexdigest(application.document_number.to_s).to_i(16)
        debt = seed % 80_000_000 # COP

        {
          "proveedor" => PROVIDER,
          "deuda_bancaria" => debt,
          "puntaje" => score_for(debt, application.monthly_income),
          "estado_producto" => seed.even? ? "vigente" : "en_mora"
        }
      end

      private

      def score_for(debt, monthly_income)
        income = [ monthly_income.to_i, 1 ].max
        debt_to_income = debt / income

        (850 - (debt_to_income * 10)).clamp(300, 850)
      end
    end
  end
end

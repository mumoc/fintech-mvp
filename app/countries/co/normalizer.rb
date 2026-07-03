module Countries
  module CO
    # Maps the CO provider shape (deuda_bancaria / puntaje / estado_producto) to
    # the internal BankData struct.
    class Normalizer < Base::Normalizer
      ACCOUNT_STATUS = {
        "vigente" => "active",
        "en_mora" => "delinquent"
      }.freeze

      def normalize(payload)
        Countries::BankData.new(
          total_debt: payload["deuda_bancaria"],
          credit_score: payload["puntaje"],
          account_status: ACCOUNT_STATUS.fetch(payload["estado_producto"], "unknown")
        )
      end
    end
  end
end

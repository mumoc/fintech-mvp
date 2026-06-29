module Countries
  module MX
    # Maps the MX provider shape (deuda_total / buro_score / estatus_cuenta) to
    # the internal BankData struct.
    class Normalizer < Base::Normalizer
      ACCOUNT_STATUS = {
        "activa" => "active",
        "morosa" => "delinquent"
      }.freeze

      def normalize(payload)
        Countries::BankData.new(
          total_debt: payload["deuda_total"],
          credit_score: payload["buro_score"],
          account_status: ACCOUNT_STATUS.fetch(payload["estatus_cuenta"], "unknown")
        )
      end
    end
  end
end

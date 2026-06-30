module Countries
  module ES
    # Maps the ES provider shape (total_liabilities / scoring / account_state) to
    # the internal BankData struct — the same target as MX, different source.
    class Normalizer < Base::Normalizer
      ACCOUNT_STATE = {
        "al_corriente" => "active",
        "en_mora" => "delinquent"
      }.freeze

      def normalize(payload)
        Countries::BankData.new(
          total_debt: payload["total_liabilities"],
          credit_score: payload["scoring"],
          account_status: ACCOUNT_STATE.fetch(payload["account_state"], "unknown")
        )
      end
    end
  end
end

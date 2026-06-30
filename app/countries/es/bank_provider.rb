require "digest"

module Countries
  module ES
    # Simulated Spanish provider. Returns a DIFFERENT shape from MX
    # (total_liabilities / scoring / account_state) — the Normalizer collapses it
    # to the same internal BankData. Values are deterministic from the document.
    class BankProvider < Base::BankProvider
      PROVIDER = "ES_PROVIDER".freeze

      def fetch(application)
        seed = Digest::SHA256.hexdigest(application.document_number.to_s).to_i(16)

        {
          "provider" => PROVIDER,
          "total_liabilities" => (seed % 2_000_000) / 100.0, # EUR
          "scoring" => seed % 1000,                          # 0..999 (different scale than MX)
          "account_state" => seed.even? ? "al_corriente" : "en_mora"
        }
      end
    end
  end
end

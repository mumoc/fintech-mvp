require "digest"

module Countries
  module MX
    # Simulated Mexican bureau provider. Returns an MX-specific shape; values are
    # derived deterministically from the document number so repeated fetches (and
    # tests) are stable. The Normalizer maps this shape to BankData.
    class BankProvider < Base::BankProvider
      PROVIDER = "MX_PROVIDER".freeze

      def fetch(application)
        seed = Digest::SHA256.hexdigest(application.document_number.to_s).to_i(16)

        {
          "proveedor" => PROVIDER,
          "deuda_total" => (seed % 1_500_000) / 100.0, # MXN
          "buro_score" => 300 + (seed % 551),          # 300..850
          "estatus_cuenta" => seed.even? ? "activa" : "morosa"
        }
      end
    end
  end
end

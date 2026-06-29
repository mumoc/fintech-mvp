module Countries
  module Base
    # Fetches raw bank/bureau data for an application. Each country returns its
    # own provider-specific shape; the Normalizer collapses it to BankData.
    class BankProvider
      # @return [Hash] the raw provider payload (kept verbatim for audit).
      def fetch(_application)
        raise NotImplementedError, "#{self.class} must implement #fetch"
      end
    end
  end
end

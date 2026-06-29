module Countries
  module Base
    # Maps a country-specific raw provider payload to the internal BankData
    # struct (total_debt / credit_score / account_status).
    class Normalizer
      # @param payload [Hash] raw provider response
      # @return [Countries::BankData]
      def normalize(_payload)
        raise NotImplementedError, "#{self.class} must implement #normalize"
      end
    end
  end
end

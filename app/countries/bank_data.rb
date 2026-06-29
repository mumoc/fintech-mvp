module Countries
  # Internal, country-agnostic shape that every country's Normalizer maps the
  # raw provider payload into. The rest of the system only ever sees this.
  BankData = Data.define(:total_debt, :credit_score, :account_status)
end

module Countries
  # Value object bundling a country's four strategy classes. Built by the
  # Registry from a country namespace by convention.
  Country = Data.define(:code, :validator, :bank_provider, :normalizer, :state_machine) do
    def self.for_namespace(code, namespace)
      new(
        code: code,
        validator: namespace::Validator,
        bank_provider: namespace::BankProvider,
        normalizer: namespace::Normalizer,
        state_machine: namespace::StateMachine
      )
    end
  end
end

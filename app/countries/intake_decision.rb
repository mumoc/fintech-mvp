module Countries
  # The initial status + flags a country assigns to a new application, based on
  # its intake business rule (MX income ratio, ES amount threshold, ...).
  IntakeDecision = Data.define(:status, :flags)
end

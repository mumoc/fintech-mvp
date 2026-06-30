module Applications
  # Orchestrates creation of a credit application, delegating all country-specific
  # behavior to the resolved country strategy (validator / bank provider /
  # normalizer / state machine). Returns a Result; never raises for domain
  # failures (unsupported country, invalid document, validation).
  class CreateApplication
    def self.call!(params:, actor: nil)
      new(params: params, actor: actor).call!
    end

    def initialize(params:, actor: nil)
      @params = params
      @actor = actor
    end

    def call!
      unless Countries::Registry.supported?(country_code)
        return Result.failure(:unsupported_country, "Unsupported country: #{country_code.inspect}")
      end

      application = build_application
      validator = country.validator.new(application)
      return Result.failure(:invalid_document, validator.errors) unless validator.valid?

      raw_payload = country.bank_provider.new.fetch(application)
      apply_intake_decision(application)
      persist!(application, raw_payload)

      Result.success(application)
    rescue ActiveRecord::RecordInvalid => e
      Result.failure(:validation_error, e.record.errors.full_messages)
    rescue ActiveRecord::RecordNotUnique
      Result.failure(:duplicate_document, "An application with this document already exists")
    end

    private

    attr_reader :params, :actor

    def country
      @country ||= Countries::Registry.for(country_code)
    end

    def country_code
      params[:country]
    end

    def build_application
      CreditApplication.new(
        country: country_code,
        full_name: params[:full_name],
        document_type: country.validator.document_type(params[:document_number]),
        document_number: params[:document_number],
        amount_requested: params[:amount_requested],
        monthly_income: params[:monthly_income],
        requested_at: Time.current
      )
    end

    def apply_intake_decision(application)
      decision = country.state_machine.new(application).intake
      application.status = decision.status
      application.flags = decision.flags
    end

    def persist!(application, raw_payload)
      normalized = country.normalizer.new.normalize(raw_payload)

      ApplicationRecord.transaction do
        application.save!
        application.create_bank_record!(
          provider: country.bank_provider::PROVIDER,
          total_debt: normalized.total_debt,
          credit_score: normalized.credit_score,
          account_status: normalized.account_status,
          raw_payload: raw_payload,
          fetched_at: Time.current
        )
      end
    end
  end
end

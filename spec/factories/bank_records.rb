FactoryBot.define do
  factory :bank_record do
    credit_application
    provider { "MX_PROVIDER" }
    total_debt { 15_000.00 }
    credit_score { 720 }
    account_status { "active" }
    raw_payload { { "deuda_total" => 15_000.0, "buro_score" => 720, "estatus_cuenta" => "activa" } }
    fetched_at { Time.current }
  end
end

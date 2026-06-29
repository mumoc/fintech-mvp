FactoryBot.define do
  factory :credit_application do
    country { "MX" }
    full_name { "Juana Pérez" }
    document_type { "CURP" }
    sequence(:document_number) { |n| "PEXJ800101HDFRRN#{format('%02d', n % 100)}" }
    amount_requested { 100_000.00 }
    monthly_income { 25_000.00 }
    requested_at { Time.current }
    status { "received" }

    trait :with_bank_record do
      after(:create) do |application|
        create(:bank_record, credit_application: application)
      end
    end
  end
end

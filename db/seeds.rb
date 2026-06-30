# Idempotent seed: one user per role + sample MX/ES applications.
# Run with `make seed` (./bin/rails db:seed). Safe to run repeatedly.

DEFAULT_PASSWORD = "password123".freeze

{
  "admin@bravo.test" => :admin,
  "analyst@bravo.test" => :analyst,
  "operator@bravo.test" => :operator
}.each do |email, role|
  User.find_or_create_by!(email: email) do |user|
    user.password = DEFAULT_PASSWORD
    user.role = role
  end
end
puts "Seeded users: #{User.count} (password for all: #{DEFAULT_PASSWORD})"

operator = User.find_by!(email: "operator@bravo.test")

# Goes through the real creation pipeline (country validator + bank provider +
# normalizer + intake rule + outbox). Skips documents that already exist.
[
  { country: "MX", full_name: "Juana Pérez", document_number: "HEGG560427MVZRRL04",
    amount_requested: 120_000, monthly_income: 30_000 },
  { country: "MX", full_name: "Mario Gómez", document_number: "GOMC900514HJCRRL02",
    amount_requested: 2_000_000, monthly_income: 25_000 }, # over 30x ratio -> under_review
  { country: "ES", full_name: "Carlos Ruiz", document_number: "12345678Z",
    amount_requested: 40_000, monthly_income: 4_000 },
  { country: "ES", full_name: "Lucía Soler", document_number: "00000000T",
    amount_requested: 60_000, monthly_income: 5_000 } # over EUR 50k -> under_review
].each do |attrs|
  fingerprint = CreditApplication.fingerprint_for(attrs[:document_number])
  next if CreditApplication.exists?(document_fingerprint: fingerprint)

  result = Applications::CreateApplication.call!(params: attrs, actor: operator)
  warn "  skipped #{attrs[:country]} (#{result.error.code}): #{result.error.messages.join(', ')}" if result.failure?
end
puts "Seeded applications: #{CreditApplication.count}"

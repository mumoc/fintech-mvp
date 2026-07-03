# Idempotent seed: one user per role + sample MX/ES/CO applications.
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
analyst = User.find_by!(email: "analyst@bravo.test")

# Goes through the real creation pipeline (country validator + bank provider +
# normalizer + intake rule + outbox). Skips documents that already exist.
samples = [
  { country: "MX", full_name: "Juana Pérez", document_number: "HEGG560427MVZRRL04",
    amount_requested: 120_000, monthly_income: 30_000 },
  { country: "MX", full_name: "Mario Gómez", document_number: "GOMC900514HJCRRL02",
    amount_requested: 2_000_000, monthly_income: 25_000 }, # over 30x ratio -> under_review
  { country: "ES", full_name: "Carlos Ruiz", document_number: "12345678Z",
    amount_requested: 40_000, monthly_income: 4_000 },
  { country: "ES", full_name: "Lucía Soler", document_number: "00000000T",
    amount_requested: 60_000, monthly_income: 5_000 }, # over EUR 50k -> under_review
  { country: "CO", full_name: "Camila Rojas", document_number: "1020304050",
    amount_requested: 20_000_000, monthly_income: 3_000_000 },
  { country: "CO", full_name: "Andrés Pérez", document_number: "1098765432",
    amount_requested: 100_000_000, monthly_income: 3_000_000 } # over 30x ratio -> under_review
]

created = {}
samples.each do |attrs|
  fingerprint = CreditApplication.fingerprint_for(attrs[:document_number])
  next if CreditApplication.exists?(document_fingerprint: fingerprint)

  result = Applications::CreateApplication.call!(params: attrs, actor: operator)
  if result.success?
    created[attrs[:document_number]] = result.value
  else
    warn "  skipped #{attrs[:country]} (#{result.error.code}): #{result.error.messages.join(', ')}"
  end
end

# Spread states across the freshly-created applications so the data set shows
# received / under_review / approved / rejected. Idempotent: only freshly-created
# rows are transitioned, so re-seeding leaves them in place.
{ "HEGG560427MVZRRL04" => "approve", "00000000T" => "reject" }.each do |document, event|
  application = created[document]
  next unless application

  Applications::UpdateStatus.call!(
    application: application, event: event, actor: analyst,
    expected_lock_version: application.lock_version
  )
end

puts "Seeded applications: #{CreditApplication.count} #{CreditApplication.group(:status).count}"

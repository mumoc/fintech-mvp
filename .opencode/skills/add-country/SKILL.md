---
name: add-country
description: Use when adding a new country strategy to this fintech MVP, including app/countries/<code>/, registry wiring, deterministic provider data, country specs, seeds, and verification.
---

# Add Country

## Before you start

Read `app/countries/mx/` (all four files) and `spec/countries/mx/` — they are the canonical pattern. Do not add country logic to controllers, services, jobs, or models.

## Clarify these facts before writing code

- country code (e.g. `CO`)
- document type label and validation rule
- provider payload field names and score range
- intake review rule (if different from MX's 30× income limit)

## Steps

**1. Write failing specs first:**
- `spec/countries/<code>/validator_spec.rb`
- `spec/countries/<code>/bank_provider_spec.rb`
- `spec/countries/<code>/normalizer_spec.rb`
- `spec/countries/<code>/state_machine_spec.rb`
- `spec/countries/<code>/pipeline_integration_spec.rb`
- update `spec/countries/registry_spec.rb`
- update `spec/countries/catalog_spec.rb`

**2. Implement (mirror the MX pattern):**
- add `app/countries/<code>/validator.rb` — use `is_a?(String)` when the document must be a string
- add `app/countries/<code>/bank_provider.rb` — derive all values from `Digest::SHA256.hexdigest(application.document_number.to_s).to_i(16)`; never call external services
- add `app/countries/<code>/normalizer.rb` — output `Countries::BankData(total_debt:, credit_score:, account_status:)`
- add `app/countries/<code>/state_machine.rb`
- add one line to `Countries::Registry::NAMESPACES` in `app/countries/registry.rb`
- append `"<code>" => "<CODE>"` to the existing `inflector.inflect(...)` call inside the `bravo.countries_namespace` initializer in `config/application.rb`

**3. Update operational data (when useful):**
- add seed examples in `db/seeds.rb`
- log any non-obvious behavior choices in `EXECUTION_PLAN.md → ## Assumptions log`
- touch frontend only if it has hardcoded country lists or currencies

## Required test coverage

- validator: accepts valid inputs, rejects malformed and wrong-type inputs
- bank provider: returns country-specific shape, is deterministic, score stays in range
- normalizer: maps all known/unknown statuses to `BankData`
- state machine: applies the intake rule
- pipeline integration: existing API creates the application without controller/service changes
- registry: returns the strategy bundle
- catalog: includes the new country and document type

## Commands

Prefer Docker so the Ruby version matches:

```bash
# targeted
docker compose run --rm -e RAILS_ENV=test api bash -c \
  "./bin/rails db:prepare && bundle exec rspec spec/countries/<code> spec/countries/registry_spec.rb spec/countries/catalog_spec.rb"

# full gates
make test
make lint

# only if frontend changed
make web-test && make web-build
```

## Finish checklist

- `app/countries/<code>/` has all four strategy files
- one line added to `Countries::Registry::NAMESPACES`
- `"<code>" => "<CODE>"` appended to the existing `inflector.inflect(...)` call in `config/application.rb`
- no country code added to controllers/services/jobs/models
- specs cover unit and pipeline behavior
- seeds and assumptions log updated for any non-obvious choices
- all gates pass

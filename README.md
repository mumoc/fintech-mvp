# Bravo Fintech MVP

Multi-country credit-application API for a fintech operating across LATAM and Europe.
Primary implementations: **México (MX)** and **España (ES)**, designed so that adding a
third country is configuration, not code.

> Architectural signature: *"The first implementation defines the architecture; the
> second is configuration, not code."*

## Stack

Rails 7 (API-only) · PostgreSQL · Sidekiq + Redis · JWT · Pundit · AASM · ActionCable ·
React + Tailwind · Docker Compose · Kubernetes (manifests) · Makefile.

## Quick start

Requirements: Docker + Docker Compose and `make`. No local Ruby needed — everything
runs in containers.

```bash
make up        # build + boot api, postgres, redis (waits until healthy)
curl localhost:3000/up   # => 200, the app is live

make migrate   # create/migrate the database
make seed      # load sample users and applications
make test      # run the test suite
make lint      # static analysis
make down      # stop everything
```

The API is served at `http://localhost:3000`. A clean clone boots in under 5 minutes.

Run `make help` to list all commands.

## Configuration

Development defaults (non-secret) are baked into `docker-compose.yml`. Override them by
copying `.env.example` to `.env`. Real secrets are never committed — see
`config/master.key` (git-ignored) and the Kubernetes `secrets.example.yaml`.

## Assumptions

- **Bank providers are simulated.** Each country's `BankProvider` returns a
  provider-specific shape derived deterministically from the document number
  (stable across fetches and tests). A per-country `Normalizer` maps it to one
  internal `BankData` (`total_debt` / `credit_score` / `account_status`); the raw
  payload is retained in `jsonb` for audit.
- **Encryption / blind-index / JWT keys** are read from the environment. The
  development defaults baked into `config/application.rb` and `.env.example` are
  **non-secret placeholders** — production supplies real keys via the secrets
  manager.
- **MX business rule:** `amount_requested ≤ monthly_income × 30`; a breach routes
  the application to `under_review` with a `requires_review` flag. (ES amount
  threshold arrives with the second country.)
- **Deliberately out of scope for now** (see `EXECUTION_PLAN.md → Backlog`): rate
  limiting, circuit breakers, dead-letter queues, Prometheus metrics, tracing.

## Data model

UUID primary keys throughout (multi-country fintech: avoids collisions and does
not leak volume through sequential IDs).

```
users                       credit_applications              bank_records
─────                       ───────────────────              ────────────
id (uuid, pk)               id (uuid, pk)            1     1  id (uuid, pk)
email (citext, uniq)        country                ───────  credit_application_id (fk)
password_digest             full_name      (enc)             provider
role (enum)                 document_number(enc, det)        total_debt   ┐ normalized
                            document_fingerprint (uniq)      credit_score │ from the raw
                            monthly_income (enc)             account_status┘ provider shape
                            amount_requested                 raw_payload (jsonb)
                            status / risk_score / flags      fetched_at
                            lock_version (optimistic)
                                  │ 1
                                  │ N           state_transitions
                                  └───────────  id, from_state, to_state, actor_id,
                                                reason, metadata, created_at
```

Key decisions:

- **PII at rest** (`full_name`, `document_number`, `monthly_income`) is encrypted
  with Active Record encryption. `document_number` uses **deterministic**
  encryption so it stays searchable for dedupe; the others use stronger
  **non-deterministic** encryption. `amount_requested` is not PII → plaintext.
- **`document_fingerprint`** is a keyed HMAC of the normalized document number,
  uniquely indexed — dedupe/lookup without ever decrypting.
- **`bank_records.raw_payload` (`jsonb`)** keeps the provider response verbatim,
  decoupling the domain from provider shape changes (only the Normalizer moves).
- **Indexes:** `(country, status, created_at)` for the critical listing query;
  unique `(document_fingerprint)`; FK indexes.

## Documentation (filled in as the build progresses)

- **Technical decisions** — each with its tradeoff.
- **Security** — PII encryption, JWT, Pundit roles, scope-aware serializers, HMAC webhooks.
- **Scalability** — indexes, partitioning, archival, critical queries, bottlenecks.
- **Concurrency** — transactional outbox + `SKIP LOCKED`, idempotent jobs, optimistic locking.
- **Caching** — versioned keys, country-config TTL.
- **Webhooks** — idempotent inbound, signed outbound with retries.
- **How to add a country** — the four classes under `app/countries/<code>/` + one registry line.

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

## Documentation (filled in as the build progresses)

- **Assumptions** — simulated bank providers, external webhook endpoint, deliberate scope cuts.
- **Data model** — ERD, UUID PKs, `jsonb` raw payloads, deterministic vs non-deterministic PII encryption.
- **Technical decisions** — each with its tradeoff.
- **Security** — PII encryption, JWT, Pundit roles, scope-aware serializers, HMAC webhooks.
- **Scalability** — indexes, partitioning, archival, critical queries, bottlenecks.
- **Concurrency** — transactional outbox + `SKIP LOCKED`, idempotent jobs, optimistic locking.
- **Caching** — versioned keys, country-config TTL.
- **Webhooks** — idempotent inbound, signed outbound with retries.
- **How to add a country** — the four classes under `app/countries/<code>/` + one registry line.

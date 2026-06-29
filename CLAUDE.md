# CLAUDE.md — Bravo Fintech MVP

Project memory for AI agents working in this repo. Loaded every session. Read it fully before acting.

---

## Project

Multi-country credit-application MVP for a fintech operating across LATAM and Europe. Primary
implementation: **México (MX)** and **España (ES)**, designed so a third country is configuration,
not code. Built as a technical exercise; treat it as production-quality.

## How to work here

1. **`EXECUTION_PLAN.md` is the single source of truth for build state.** Execute the next `[ ]` task
   whose `depends_on` is satisfied. Follow its operating contract exactly.
2. **`PLAN_Bravo_Fintech_MVP.md` is the design spec.** Consult it for the *how/why* (data model,
   acceptance criteria, scalability detail) whenever a task needs depth.
3. **Gate before done.** A task is `[x]` only when its `GATE` command passes. No green gate, no done.
   If you can't make it green, mark `[!]` with a one-line blocker and move on.
4. **State update ships with the code.** Update the task box in `EXECUTION_PLAN.md` in the *same commit*
   as the work. One task = one logical commit, conventional-commit style.
5. **Read before modify. Never skip hooks. No scope creep.** Defer unrequested ideas to the plan's
   `## Backlog`.

## Stack

Rails 7 (API-only) · PostgreSQL · Sidekiq + Redis · JWT (auth) · Pundit (authz) · AASM (state
machines) · ActionCable (realtime) · React + Tailwind (frontend) · Docker Compose · Kubernetes
(manifests only) · Makefile.

## Architecture principles

- **Signature:** *"The first implementation defines the architecture; the second is configuration,
  not code."* Adding a country must mean adding `app/countries/<code>/` + one line in the registry,
  and nothing else.
- **Country logic is sealed.** All country-specific behavior (validator, bank provider, normalizer,
  state machine) lives under `app/countries/<code>/`, resolved through `Countries::Registry.for(code)`.
  Country codes (`"MX"`, `"ES"`) must never appear in controllers, services, jobs, or models.
- **Async = transactional outbox + `SELECT ... FOR UPDATE SKIP LOCKED`.** A PG trigger writes to
  `outbox_events` in the same transaction as the state change; dispatchers claim events with
  `SKIP LOCKED` so N workers run in parallel without double-processing.
- **Layered:** controllers → services → repositories/models → integration. No business logic in
  controllers.
- **Bank data is a mini-ETL:** each provider returns a different shape; a per-country Normalizer maps
  it to one internal struct (`total_debt` / `credit_score` / `account_status`). Raw payload is kept
  in `jsonb` for audit.

## Non-negotiable conventions

- **TDD, mandatory.** Red → green → refactor. Failing test first, always.
- **Result pattern.** Services return `Success`/`Failure`. No exceptions as flow control.
- **Naming:** failure-raising service methods end in `!`; boolean methods end in `?`.
- **Jobs receive IDs, never objects, and are idempotent** (check state before acting).
- **Queries:** eager-load associations; `exists?` over `present?` on relations; `find_each` for batches.
- **Logging:** structured JSON only, keys `event:` / `country:` / `application_id:`. **Never log PII**
  (`document_number`, `monthly_income`, `full_name`).
- **PII at rest:** encrypted. Deterministic encryption only where the field must be searchable
  (`document_number`); serializers are scope-aware and hide PII from unauthorized roles.
- **Migrations are reversible** — triggers/functions get explicit `up`/`down`.
- **No over-engineering.** The outbox is enough; don't reach for event sourcing or CQRS.

## Commands

```
make up        # boot api + postgres + redis (must be < 5 min on a clean clone)
make migrate   # run migrations (incl. PL/pgSQL triggers)
make seed      # users per role + sample MX/ES applications
make test      # full suite — must be green before any task is done
make lint      # rubocop + bundler-audit — must be clean
make console
```

## Quality bar (definition of done)

`make up && make seed` boots a fresh clone in < 5 min, `make test` is green, `make lint` is clean,
no N+1 (bullet enabled in test), and no PII or secret appears in logs or repo.

## Do not

- Hardcode a country code outside `app/countries/`.
- Mark a task done without a green gate.
- Commit real secrets (use `secrets.example.yaml` / `.env.example`).
- Log PII in any form.
- Ship a job that mutates state without an idempotency guard.

## When unsure

If a decision isn't specified here or in the plan, pick the option consistent with these conventions
and record it in `EXECUTION_PLAN.md → ## Assumptions log`. Do not branch silently.

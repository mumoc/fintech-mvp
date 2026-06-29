# EXECUTION_PLAN — Bravo Fintech MVP (MX + ES)

> **Single source of truth for build state.** This file is updated by whoever (human or AI agent)
> is executing the build. The detailed spec lives in `PLAN_Bravo_Fintech_MVP.md` — consult it for
> *how/why*; this file is *what/when/state*.

---

## AGENT OPERATING CONTRACT — read first, every session

You are building this system task by task. Follow this contract exactly.

1. **State legend** — update the box on each task as you work:
   - `[ ]` todo · `[~]` in_progress · `[x]` done · `[!]` blocked
2. **Order** — execute tasks top to bottom. Never start a task whose `depends_on` is not `[x]`.
3. **Gate before done** — every task has a `GATE`. You may only set `[x]` when the gate command
   passes with the expected result. **No green gate, no done.** If you cannot make it green, set
   `[!]`, write the blocker in one line under the task, and move to the next task whose deps are met.
4. **State update is part of the task** — after finishing a task, update its box in this file in the
   **same commit** as the code. One task = one logical commit (conventional commits).
5. **Read before modify.** Inspect existing files before editing. Never skip git hooks.
6. **No arbitrary choices.** If a decision isn't specified here or in the spec, pick the option that
   matches the conventions below and record it under `## Assumptions log` at the bottom — do not
   silently branch.
7. **No scope creep.** Build exactly the task. Defer ideas to `## Backlog (out of scope now)`.

---

## NON-NEGOTIABLE CONVENTIONS — do not drift

- **TDD, mandatory.** Red → green → refactor. Write the failing test first, always.
- **Result pattern.** Service objects return `Success`/`Failure`. No exceptions as flow control.
- **Naming.** Service methods that can fail / raise: `!`. Boolean methods: `?`.
- **Jobs.** Receive **IDs**, never objects. Must be **idempotent** (check state before acting).
- **Queries.** Eager-load associations. Use `exists?` over `present?` on relations. `find_each` for batches.
- **Logging.** Structured JSON only, with keys `event:`, `country:`, `application_id:`. **Never log PII**
  (`document_number`, `monthly_income`, `full_name`) in clear text.
- **Country logic is sealed.** Anything country-specific lives under `app/countries/<code>/`. If a task
  forces you to write `"MX"`/`"ES"` anywhere in controllers, services, jobs, or models → that's an
  architecture leak; stop and route it through `Countries::Registry`.
- **Migrations are reversible.** Triggers/functions get explicit `up`/`down`.
- **No secrets committed.** Use `secrets.example.yaml` / `.env.example` only.

---

## GLOBAL DEFINITION OF DONE (the build is complete when)

`make up && make seed` on a fresh clone boots in **< 5 min**, `make test` is green, `make lint` is
clean, the Deliverables Checklist (bottom) is fully checked, and no PII/secret is present in logs or repo.

---

# MILESTONE M1 — Foundation & synchronous API  *(Day 1)*

### `[ ]` T001 — Project bootstrap
- **depends_on:** —
- **do:** Rails 7 API-only app. `docker-compose.yml` with services: `api`, `postgres`, `redis`.
  `Makefile` skeleton (`up`, `down`, `test`, `lint`, `migrate`, `console`). Health endpoint `GET /up`.
- **GATE:** `make up` boots all containers; `curl localhost:3000/up` → `200`; `make test` runs (0 tests OK).
- **dod:** Fresh clone boots; README "Quick start" stub written.

### `[ ]` T002 — Quality gates
- **depends_on:** T001
- **do:** RSpec, RuboCop, `bundler-audit`, `bullet` (enabled in test env to detect N+1). Wire into Makefile.
- **GATE:** `make lint` clean; `make test` passes; `bundler-audit` reports no known CVEs.

### `[ ]` T003 — Schema foundations
- **depends_on:** T002
- **do:** Enable `pgcrypto`. Migrations (UUID PKs): `users`, `credit_applications`, `bank_records`,
  `state_transitions`. ActiveRecord encryption: deterministic for `document_number`, non-deterministic
  for `full_name`/`monthly_income`. Add `document_fingerprint` (blind index, unique). Base indexes:
  `(country, status, created_at)`, unique `(document_fingerprint)`.
- **GATE:** `make migrate` green; model specs pass — PII columns encrypted at rest, validations present,
  fingerprint uniqueness enforced.

### `[ ]` T004 — Authentication (JWT)
- **depends_on:** T003
- **do:** `Auth::SessionsController#create` → JWT on valid creds. Token-verify concern guarding the API.
- **GATE:** request spec — valid login → `200` + token; protected endpoint without token → `401`;
  tampered/expired token → `401`.

### `[ ]` T005 — Authorization (Pundit)
- **depends_on:** T004
- **do:** Roles `admin`/`analyst`/`operator`. `CreditApplicationPolicy` (operator: create/read;
  analyst: + change_status; admin: all). Scope-aware serializer hides PII from unauthorized roles.
- **GATE:** policy specs cover allow + deny per role; serializer spec — `operator` response omits
  `document_number`/`monthly_income`.

### `[ ]` T006 — Country registry + MX strategy
- **depends_on:** T003
- **do:** `Countries::Registry.for(code)` returning a config with `validator`/`bank_provider`/
  `normalizer`/`state_machine`. Base interfaces under `countries/base/`. Implement **MX**: `Validator`
  (CURP format + check digit), `BankProvider` (simulated MX shape), `Normalizer` (MX shape → internal
  `total_debt`/`credit_score`/`account_status`).
- **GATE:** unit specs — valid CURP passes, malformed/invalid-check-digit CURP fails; normalizer maps
  MX payload to internal struct.

### `[ ]` T007 — Create application (service + endpoint)
- **depends_on:** T005, T006
- **do:** `Result`. `Applications::CreateApplication.call!` → validates via country validator, fetches +
  normalizes bank data, persists, sets initial state, applies MX rule (income/amount ratio). Wire
  `POST /api/v1/credit_applications`.
- **GATE:** service specs (success + each failure path); request specs — `201` valid; `422` invalid
  document; `422` unsupported country; `bank_record` persisted; MX ratio breach → correct flag/state.

### `[ ]` T008 — Read + list
- **depends_on:** T007
- **do:** `GET /credit_applications/:id` (scope-aware, eager-load `bank_record`). `GET /credit_applications`
  with filters `country`, `status`, `from`/`to`, **paginated**.
- **GATE:** request specs — show `200`/`404`; filter by country returns only that country; pagination
  present; **bullet asserts no N+1**.

> **M1 CHECKPOINT** — authenticated sync CRUD, one country, fully tested. README has Quick start,
> Assumptions, Data model (ERD started). Commit tag `m1-complete`.

---

# MILESTONE M2 — Async, state machine, second country  *(Day 2)*

### `[ ]` T009 — State machine + status update
- **depends_on:** T008
- **do:** AASM state machine (MX) wired via registry. `Applications::UpdateStatus`. Record every
  transition in `state_transitions`. Optimistic locking via `lock_version`.
- **GATE:** valid transition → `200` + transition row; invalid transition (guard) → `422`, state
  unchanged; stale `lock_version` → `409`.

### `[ ]` T010 — PG triggers: outbox + audit
- **depends_on:** T009
- **do:** Reversible migration with PL/pgSQL. Trigger on `credit_applications`/`state_transitions`
  inserts into `outbox_events` **within the same transaction**. Generic audit trigger writes
  old/new diff into `audit_logs`. Partial index `outbox_events(processed_at) WHERE processed_at IS NULL`.
- **GATE:** spec — a state change inserts exactly one `outbox_event` in the same tx (transaction
  rollback → no event row); an update writes one `audit_log` row with correct diff.

### `[ ]` T011 — Outbox dispatcher (parallel-safe)
- **depends_on:** T010
- **do:** `OutboxDispatchJob` claims pending events with `SELECT ... FOR UPDATE SKIP LOCKED LIMIT N`,
  enqueues the matching Sidekiq job, marks `processed_at`. Recurring schedule. Designed to run as
  multiple replicas.
- **GATE:** spec — two concurrent dispatchers never claim the same event (`SKIP LOCKED`); dispatched
  events are marked processed exactly once.

### `[ ]` T012 — Risk job + structured logging
- **depends_on:** T011
- **do:** `RiskEvaluationJob` (receives application **id**, idempotent — checks state before writing
  `risk_score`). `StructuredLogger` emitting JSON with `event:`/`country:`/`application_id:`.
- **GATE:** spec — running the job twice for the same id yields a single effect; logs contain required
  keys and **no PII**.

### `[ ]` T013 — Webhooks (inbound + outbound)
- **depends_on:** T011
- **do:** Outbound: `WebhookDeliveryJob` POSTs to a simulated external endpoint on state change, HMAC
  signed, Sidekiq retries, records `webhook_deliveries`. Inbound: `WebhooksController#bank` verifies
  signature, dedupes by `idempotency_key`, updates the application (state/data confirmation).
- **GATE:** outbound spec — posts payload, logs delivery, retries on failure; inbound spec — repeated
  `idempotency_key` is processed only once and mutates the application as expected.

### `[ ]` T014 — Caching
- **depends_on:** T008
- **do:** Cache single-application reads, key versioned by `updated_at` (write → key changes →
  auto-invalidation). Cache country config with long TTL.
- **GATE:** spec — second read served from cache; after update the cache key changes (stale data not
  served); country config served from cache within TTL.

### `[ ]` T015 — Add ES  *(the signature task — time-box ≤ 1h)*
- **depends_on:** T006, T009, T013
- **do:** Implement **ES** strategy only by adding `countries/es/` (Validator: DNI 8-digit + **mod-23
  letter check**; BankProvider with a *different* shape; Normalizer mapping it to the internal struct;
  StateMachine) and registering it. **Touch nothing in controllers/services/jobs/models.**
- **GATE:** ES specs — valid DNI passes, wrong control letter fails; `amount_requested > threshold` →
  `requires_review` / `under_review`; existing MX specs still green.
- **dod:** Record in the README the **elapsed time** and the **count of non-`countries/es/` files
  changed** (target: 1 — the registry). This is the architectural-signature evidence.

> **M2 CHECKPOINT** — backend complete, two countries, async pipeline solid. README has Technical
> decisions, Security, Concurrency, Caching, Webhooks. Commit tag `m2-complete`.

---

# MILESTONE M3 — Frontend, infra, README  *(Day 3)*

### `[ ]` T016 — Frontend (React + Tailwind)
- **depends_on:** T008, T009
- **do:** Views: create application, list (with filters), detail, update status. Explicit error
  handling (validation errors surfaced, network failures shown).
- **GATE:** app builds; list renders from API; submitting an invalid document shows the `422` message;
  minimal component tests pass.

### `[ ]` T017 — Realtime (ActionCable)
- **depends_on:** T016, T011
- **do:** Broadcast on create + state change. `ApplicationsChannel`. Client subscribes; list/detail
  update without refresh.
- **GATE:** e2e smoke — changing an application's state via API updates the open UI within ~1s, no reload.

### `[ ]` T018 — Kubernetes manifests
- **depends_on:** T015
- **do:** YAML for `api`, `worker` (Sidekiq), `dispatcher`, `frontend`, `postgres`, `redis`, plus
  `services`, `ingress`, `configmap`, `secrets.example.yaml`. No real deploy.
- **GATE:** `kubectl apply --dry-run=client -f k8s/` validates every manifest; grep confirms no real
  secret values committed.

### `[ ]` T019 — Makefile + seeds finalize
- **depends_on:** T016
- **do:** Complete Makefile (`run`, `test`, `migrate`, `seed`, `lint`, `deploy`). Seed data: users per
  role + sample MX/ES applications across states.
- **GATE:** **fresh clone** → `make up && make seed` completes < 5 min; end-to-end smoke passes.

### `[ ]` T020 — README: scalability + finalize
- **depends_on:** all above
- **do:** Write the scalability analysis (indexes, partitioning by `LIST(country)` + `RANGE(created_at)`,
  archival of terminal-state partitions, critical queries, bottlenecks). Add architecture diagram and
  "What I'd do with more time". Verify every Deliverables Checklist item.
- **GATE:** all README deliverable sections present (see spec §6); Deliverables Checklist fully `[x]`.

> **M3 CHECKPOINT** — shippable. Commit tag `v1.0`. Repo public, clean, no secrets.

---

## RED FLAGS — stop conditions (if any is true, STOP and fix before continuing)

- `make up` fails on a clean clone → fix before any other task (req 4.4 is gating).
- A `GATE` cannot be made green → mark the task `[!]`, never `[x]`. Do not fake completion.
- Adding ES (T015) required editing a controller/service/job/model → architecture leak; refactor the
  registry until the only non-`countries/es/` change is registration.
- PII (`document_number`/`monthly_income`/`full_name`) appears in any log line → fix logger immediately.
- Any real secret about to be committed → abort the commit.
- A job mutates state without an idempotency check → it is not done; add the guard.

---

## DELIVERABLES CHECKLIST (req mapping — agent self-verifies at T020)

- `[ ]` Create / validate-per-country / bank integration / show / list / update-status  (req 3.1–3.6)
- `[ ]` Async via DB trigger → queue  (req 3.7)
- `[ ]` Webhook inbound or outbound integrated with application model  (req 3.8)
- `[ ]` Parallel workers without inconsistency (SKIP LOCKED documented)  (req 3.9)
- `[ ]` Near-realtime frontend  (req 3.10, §5)
- `[ ]` Layered architecture, country/provider extensible without disruptive change  (req 4.1)
- `[ ]` JWT + basic authorization + PII handling  (req 4.2)
- `[ ]` Structured logs + explicit error handling + async traceability  (req 4.3)
- `[ ]` Reproducible, README install < 5 min  (req 4.4)
- `[ ]` Scalability analysis in README (indexes/partitioning/archival/queries)  (req 4.5)
- `[ ]` Queue tech explained + produce/consume shown  (req 4.6)
- `[ ]` Caching + invalidation strategy documented  (req 4.7)
- `[ ]` K8s manifests for all components  (req 4.8)
- `[ ]` Frontend: create/list/detail/update-status/realtime + error handling  (§5)
- `[ ]` README full (assumptions, data model, decisions, security, scalability, concurrency/queue/cache/webhooks)  (§6)
- `[ ]` Makefile / Justfile with standard commands  (§6.4)

---

## Assumptions log
> Agent appends every non-specified decision here, one line each.
- (e.g.) MX ratio threshold = amount_requested ≤ monthly_income × 30 — chosen as plausible consumer-credit cap.
- (e.g.) ES additional-review threshold = €50,000.

## Backlog (out of scope now)
> Deferred ideas; do not build unless a task references them.
- Rate limiting, circuit breaker on provider failure, dead-letter queue, Prometheus metrics, distributed tracing.

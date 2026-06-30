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

### `[x]` T001 — Project bootstrap
- **depends_on:** —
- **do:** Rails 7 API-only app. `docker-compose.yml` with services: `api`, `postgres`, `redis`.
  `Makefile` skeleton (`up`, `down`, `test`, `lint`, `migrate`, `console`). Health endpoint `GET /up`.
- **GATE:** `make up` boots all containers; `curl localhost:3000/up` → `200`; `make test` runs (0 tests OK).
- **dod:** Fresh clone boots; README "Quick start" stub written.

### `[x]` T002 — Quality gates
- **depends_on:** T001
- **do:** RSpec, RuboCop, `bundler-audit`, `bullet` (enabled in test env to detect N+1). Wire into Makefile.
- **GATE:** `make lint` clean; `make test` passes; `bundler-audit` reports no known CVEs.

### `[x]` T003 — Schema foundations
- **depends_on:** T002
- **do:** Enable `pgcrypto`. Migrations (UUID PKs): `users`, `credit_applications`, `bank_records`,
  `state_transitions`. ActiveRecord encryption: deterministic for `document_number`, non-deterministic
  for `full_name`/`monthly_income`. Add `document_fingerprint` (blind index, unique). Base indexes:
  `(country, status, created_at)`, unique `(document_fingerprint)`.
- **GATE:** `make migrate` green; model specs pass — PII columns encrypted at rest, validations present,
  fingerprint uniqueness enforced.

### `[x]` T004 — Authentication (JWT)
- **depends_on:** T003
- **do:** `Auth::SessionsController#create` → JWT on valid creds. Token-verify concern guarding the API.
- **GATE:** request spec — valid login → `200` + token; protected endpoint without token → `401`;
  tampered/expired token → `401`.

### `[x]` T005 — Authorization (Pundit)
- **depends_on:** T004
- **do:** Roles `admin`/`analyst`/`operator`. `CreditApplicationPolicy` (operator: create/read;
  analyst: + change_status; admin: all). Scope-aware serializer hides PII from unauthorized roles.
- **GATE:** policy specs cover allow + deny per role; serializer spec — `operator` response omits
  `document_number`/`monthly_income`.

### `[x]` T006 — Country registry + MX strategy
- **depends_on:** T003
- **do:** `Countries::Registry.for(code)` returning a config with `validator`/`bank_provider`/
  `normalizer`/`state_machine`. Base interfaces under `countries/base/`. Implement **MX**: `Validator`
  (CURP format + check digit), `BankProvider` (simulated MX shape), `Normalizer` (MX shape → internal
  `total_debt`/`credit_score`/`account_status`).
- **GATE:** unit specs — valid CURP passes, malformed/invalid-check-digit CURP fails; normalizer maps
  MX payload to internal struct.

### `[x]` T007 — Create application (service + endpoint)
- **depends_on:** T005, T006
- **do:** `Result`. `Applications::CreateApplication.call!` → validates via country validator, fetches +
  normalizes bank data, persists, sets initial state, applies MX rule (income/amount ratio). Wire
  `POST /api/v1/credit_applications`.
- **GATE:** service specs (success + each failure path); request specs — `201` valid; `422` invalid
  document; `422` unsupported country; `bank_record` persisted; MX ratio breach → correct flag/state.

### `[x]` T008 — Read + list
- **depends_on:** T007
- **do:** `GET /credit_applications/:id` (scope-aware, eager-load `bank_record`). `GET /credit_applications`
  with filters `country`, `status`, `from`/`to`, **paginated**.
- **GATE:** request specs — show `200`/`404`; filter by country returns only that country; pagination
  present; **bullet asserts no N+1**.

> **M1 CHECKPOINT** — authenticated sync CRUD, one country, fully tested. README has Quick start,
> Assumptions, Data model (ERD started). Commit tag `m1-complete`.

---

# MILESTONE M2 — Async, state machine, second country  *(Day 2)*

### `[x]` T009 — State machine + status update
- **depends_on:** T008
- **do:** AASM state machine (MX) wired via registry. `Applications::UpdateStatus`. Record every
  transition in `state_transitions`. Optimistic locking via `lock_version`.
- **GATE:** valid transition → `200` + transition row; invalid transition (guard) → `422`, state
  unchanged; stale `lock_version` → `409`.

### `[x]` T010 — PG triggers: outbox + audit
- **depends_on:** T009
- **do:** Reversible migration with PL/pgSQL. Trigger on `credit_applications`/`state_transitions`
  inserts into `outbox_events` **within the same transaction**. Generic audit trigger writes
  old/new diff into `audit_logs`. Partial index `outbox_events(processed_at) WHERE processed_at IS NULL`.
- **GATE:** spec — a state change inserts exactly one `outbox_event` in the same tx (transaction
  rollback → no event row); an update writes one `audit_log` row with correct diff.

### `[x]` T011 — Outbox dispatcher (parallel-safe)
- **depends_on:** T010
- **do:** `OutboxDispatchJob` claims pending events with `SELECT ... FOR UPDATE SKIP LOCKED LIMIT N`,
  enqueues the matching Sidekiq job, marks `processed_at`. Recurring schedule. Designed to run as
  multiple replicas.
- **GATE:** spec — two concurrent dispatchers never claim the same event (`SKIP LOCKED`); dispatched
  events are marked processed exactly once.

### `[x]` T012 — Risk job + structured logging
- **depends_on:** T011
- **do:** `RiskEvaluationJob` (receives application **id**, idempotent — checks state before writing
  `risk_score`). `StructuredLogger` emitting JSON with `event:`/`country:`/`application_id:`.
- **GATE:** spec — running the job twice for the same id yields a single effect; logs contain required
  keys and **no PII**.

### `[x]` T013 — Webhooks (inbound + outbound)
- **depends_on:** T011
- **do:** Outbound: `WebhookDeliveryJob` POSTs to a simulated external endpoint on state change, HMAC
  signed, Sidekiq retries, records `webhook_deliveries`. Inbound: `WebhooksController#bank` verifies
  signature, dedupes by `idempotency_key`, updates the application (state/data confirmation).
- **GATE:** outbound spec — posts payload, logs delivery, retries on failure; inbound spec — repeated
  `idempotency_key` is processed only once and mutates the application as expected.

### `[x]` T014 — Caching
- **depends_on:** T008
- **do:** Cache single-application reads, key versioned by `updated_at` (write → key changes →
  auto-invalidation). Cache country config with long TTL.
- **GATE:** spec — second read served from cache; after update the cache key changes (stale data not
  served); country config served from cache within TTL.

### `[x]` T015 — Add ES  *(the signature task — time-box ≤ 1h)*
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

### `[x]` T016 — Frontend (React + Tailwind)
- **depends_on:** T008, T009
- **do:** Views: create application, list (with filters), detail, update status. Explicit error
  handling (validation errors surfaced, network failures shown).
- **GATE:** app builds; list renders from API; submitting an invalid document shows the `422` message;
  minimal component tests pass.

### `[x]` T017 — Realtime (ActionCable)
- **depends_on:** T016, T011
- **do:** Broadcast on create + state change. `ApplicationsChannel`. Client subscribes; list/detail
  update without refresh.
- **GATE:** e2e smoke — changing an application's state via API updates the open UI within ~1s, no reload.

### `[x]` T018 — Kubernetes manifests
- **depends_on:** T015
- **do:** YAML for `api`, `worker` (Sidekiq), `dispatcher`, `frontend`, `postgres`, `redis`, plus
  `services`, `ingress`, `configmap`, `secrets.example.yaml`. No real deploy.
- **GATE:** `kubectl apply --dry-run=client -f k8s/` validates every manifest; grep confirms no real
  secret values committed.

### `[x]` T019 — Makefile + seeds finalize
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
- [T001] Ruby pinned to 3.3.6; dev gems install into a named volume via `bin/docker-entrypoint` so a Gemfile change needs no image rebuild. `database.yml` is fully env-driven (one file for local/CI/k8s).
- [T002] Rails bumped 7.1.2 → 7.2.3.1 (still the Rails 7 line). bundler-audit flagged 9 CVEs in 7.1.6 (Action View/Storage/Support) with fixes only available in `>= 7.2.3.1`; security gate forced the bump. Adopted `config.load_defaults 7.2`.
- [T002] RuboCop ruleset = `rubocop-rails-omakase` (Rails' curated style) — low-friction, idiomatic; keeps lint out of the way of the TDD flow.
- [T002] Bullet: raise on N+1 in test (fails the suite), log in development; unused-eager-loading checks disabled (noisy, not what we gate on).
- [T003] All domain tables use UUID PKs (`gen_random_uuid()` via pgcrypto); `citext` enabled for `users.email`.
- [T003] PII columns are `text` (hold ciphertext): `full_name`/`monthly_income` non-deterministic, `document_number` deterministic (searchable/dedupe). `monthly_income` keeps decimal semantics via `attribute :decimal` + `encrypts`. `amount_requested` is non-PII → plaintext `decimal(15,2)`.
- [T003] `document_fingerprint` = HMAC-SHA256(blind_index_key, document_number.strip.upcase), unique-indexed for dedupe without decrypting.
- [T003] `users.role` integer-backed enum {operator:0, analyst:1, admin:2}; `has_secure_password` (bcrypt added).
- [T003] `state_transitions` is append-only (created_at only, DB default `CURRENT_TIMESTAMP`).
- [T003] AR encryption keys + blind-index key read from ENV with NON-SECRET dev defaults, set in `config/application.rb` so the `active_record.encryption` railtie applies them before `config/initializers` run.
- [T004] JWT: HS256, 24h expiry, payload `{sub, role, exp}`; signed with `ENV["JWT_SECRET"]` (falls back to `secret_key_base` in dev). `JsonWebToken.decode` returns nil for any invalid/expired/tampered token → uniform 401.
- [T004] Auth is global: `Authenticatable` concern in `ApplicationController` (`before_action :authenticate_request!`); public endpoints opt out via `skip_before_action`. Routes: `POST /api/v1/login` (public), `GET /api/v1/me` (protected, used to exercise the 401 paths).
- [T004][dev-note] Adding a brand-new top-level `app/<dir>/` (e.g. `controllers/concerns`) requires an `api` container restart so Zeitwerk registers it as an autoload root; `make test` is unaffected (fresh boot per run).
- [T005] Role matrix: operator = create+read; analyst = +update_status; admin = all (`CreditApplicationPolicy`). Pundit wired into `ApplicationController` with `pundit_user = current_user` and `Pundit::NotAuthorizedError → 403`.
- [T005] PII visibility: `view_pii?` = analyst||admin. `CreditApplicationSerializer` is a PORO taking `(application, user:)`; it always returns non-PII fields and adds full_name/document_number/monthly_income only when `view_pii?` is true (operators get a redacted view).
- [T006] Country strategies live under `app/countries/<code>/` and resolve as `Countries::<CODE>::<Strategy>`. Rails would otherwise treat `app/countries` as an autoload root (stripping the namespace), so `config/application.rb` maps the dir to the `Countries` namespace via a `before: :set_autoload_paths` initializer + Zeitwerk inflections `mx→MX`, `es→ES`.
- [T006] `Countries::Registry.for(code)` builds a `Country` (Data) from a country namespace by convention (`namespace::Validator/BankProvider/Normalizer/StateMachine`). Adding a country = `app/countries/<code>/` + ONE line in `Registry::NAMESPACES`.
- [T006] Internal normalized bank shape = `Countries::BankData(total_debt, credit_score, account_status)`. MX provider is simulated, deterministic from `document_number` (stable across fetches/tests).
- [T006] MX CURP validation = strict format regex (incl. 32 state codes + NE) + RENAPO check-digit algorithm. `Countries::MX::StateMachine` is a placeholder (`INITIAL_STATE`); full AASM graph lands in T009.
- [T007] Result pattern: `Result.success(value)` / `Result.failure(code, messages)`; domain failures are returned, not raised. `CreateApplication.call!` rescues unexpected `RecordInvalid`/`RecordNotUnique` into failures.
- [T007] MX intake business rule is sealed in `Countries::MX::StateMachine#intake` (keeps the 4-strategy contract). `RATIO_LIMIT = 30`: `amount_requested > monthly_income * 30` → status `under_review` + `flags{requires_review:true, reason}`; otherwise initial state `received`.
- [T007] `document_type` is derived from the country via `validator.document_type(document_number)` (per-document classification — e.g. ES returns DNI vs NIE; default = the country's single type), not sent by the client; `bank_record.provider` from `BankProvider::PROVIDER`; `requested_at` set server-side. bank fetch+persist happen in one transaction.
- [T007] All create domain failures → HTTP 422 (`unsupported_country` / `invalid_document` / `validation_error` / `duplicate_document`). Use Rack 3.2 symbol `:unprocessable_content`.
- [T008] Listing via `Applications::Search` query object: filters `country`/`status`/`created_at` range (`from`/`to`), eager-loads `bank_record` (no N+1, Bullet-enforced), orders by `created_at desc`, offset pagination (default per_page 25, max 100) with `meta{page,per_page,total,total_pages}`; runs on `policy_scope`.
- [T008] Serializer now includes a non-PII `bank_record` summary (provider/total_debt/credit_score/account_status). `show` eager-loads `bank_record`; `ActiveRecord::RecordNotFound → 404`.
- [T009] AASM lives in `Countries::Base::StateMachine` (a PORO wrapping the application), inherited by each country — keeps the model free of state/country logic. AASM persistence hooks (`aasm_read_state`/`aasm_write_state`) make the wrapped application's `status` the source of truth. Shared transition graph: received → under_review/approved/rejected/cancelled; under_review → approved/rejected/cancelled. A country can override the graph; MX uses the shared one.
- [T009] `Applications::UpdateStatus`: validates via `may_<event>?`, fires the event, records a `state_transition`, persists in a transaction. Unknown/guard-blocked event → `:invalid_transition` (422, state unchanged). Optimistic locking: the client's `lock_version` is assigned to the loaded record before save; mismatch → `ActiveRecord::StaleObjectError` → `:conflict` (409). The transition-validity check runs before the lock check.
- [T009] `PATCH /api/v1/credit_applications/:id/status` (Pundit `update_status?` = analyst/admin; operator → 403). Body: `{credit_application:{event, lock_version, reason}}`.
- [T010] Schema format switched to `:sql` (`db/structure.sql`) so PL/pgSQL triggers/functions are captured and exist in the test DB; `db/schema.rb` removed.
- [T010] Postgres pinned to **15-alpine** to match the Debian-bookworm `pg_dump` client (a 16 server broke the `structure.sql` dump with a version mismatch). No feature in use needs 16.
- [T010] Outbox trigger on `credit_applications` emits **exactly one** event: INSERT → `created`, status-changing UPDATE → `status_changed` (payload = status/country/from/to — never PII). `state_transitions` does not emit (avoids double events). Partial index `(created_at) WHERE processed_at IS NULL` for the dispatcher.
- [T010] Generic `write_audit_log` trigger on `credit_applications` writes the old/new row image to `audit_logs`; encrypted columns are captured as ciphertext (no plaintext PII).
- [T011] `Outbox::Dispatcher` claims pending events with `FOR UPDATE SKIP LOCKED` in a transaction, enqueues via `Outbox::Router`, marks processed in the same tx → at-least-once delivery (consumers idempotent). N dispatchers run safely in parallel. `OutboxDispatchJob` (Sidekiq) drains; recurring via `sidekiq-cron` (`config/sidekiq_cron.yml`, every minute — README notes LISTEN/NOTIFY for lower latency).
- [T011] `Outbox::Router` maps `created`/`status_changed` → `RiskEvaluationJob` (skeleton here; body in T012); `WebhookDeliveryJob` is added in T013. Job names resolved by `constantize` to avoid load-order coupling.
- [T011] docker-compose `worker` service runs `sidekiq` (scale with `--scale worker=N`). `sidekiq-cron` pinned `>= 2.4` (1.12 had an XSS advisory). Concurrency spec disables transactional fixtures so `SKIP LOCKED` is exercised across real connections.
- [T012] `StructuredLogger` (`lib/structured_logger.rb`) emits one JSON line per event with `event`/`country`/`application_id`; strips PII keys (`document_number`/`monthly_income`/`full_name`) from the extra payload defensively.
- [T012] `RiskEvaluationJob` is idempotent via a conditional `UPDATE ... WHERE risk_score IS NULL` (single effect under retries/concurrency). Writing `risk_score` does not change `status`, so it never re-triggers the outbox (no loop). Score = bureau-credit + leverage heuristic, clamped 0..100.
- [T013] Webhooks signed with HMAC-SHA256 (`WebhookSignature`, `ENV[WEBHOOK_SIGNING_SECRET]`). Outbound `WebhookDeliveryJob` (routed from `status_changed`) POSTs to `WEBHOOK_ENDPOINT_URL` (simulated; default example.com), records every attempt in `webhook_deliveries`, and raises on non-2xx/network error so Sidekiq retries. HTTP via `Webhooks::Client` (Net::HTTP, stubbable).
- [T013] Inbound `POST /api/v1/webhooks/bank` (JWT-skipped, HMAC-verified over the raw body). `Webhooks::ProcessBankConfirmation` dedupes by `idempotency_key` (pre-check + unique index + race rescue) and applies the confirmation (`flags.bank_confirmed`) exactly once in a transaction. Replay → 200 no-op; bad signature → 401.
- [T014] Cache store: `redis_cache_store` (namespace `bravo:cache`) in dev/prod, `memory_store` in test. `Applications::CachedView` caches a single application's serialized view keyed by `cache_key_with_version` + PII scope — a write changes `updated_at` → new key → auto-invalidation; no cross-role PII leak. `Countries::Catalog` caches the supported-country config (code + document_type) with a 12h TTL, **keyed by the supported set** (`Registry.codes`) so adding a country auto-invalidates the catalog (no stale list); exposed at `GET /api/v1/countries`.
- [T014] Pinned `connection_pool ~> 2.4` (resolved 2.5.5): `connection_pool 3.0` changed its constructor and broke `RedisCacheStore` at boot. Test (`memory_store`) didn't catch it — the live dev smoke did.
- [M2 checkpoint] `db/seeds.rb` added (idempotent): one user per role (`*@bravo.test`, password `password123`) + 4 sample apps (MX/ES × received/under_review) created via the real pipeline. Added `has_many :webhook_deliveries, dependent: :destroy` so deliveries cascade on destroy. README expanded: mermaid architecture, <5-min setup, API tour, Technical decisions/Security/Concurrency/Caching/Webhooks. Tagged `m2-complete`. (T019 still owns the Makefile `deploy` target + final seed polish.)
- [T016] Frontend = React + Tailwind + Vite + Vitest in `frontend/` (TypeScript). Pages: login, list (country/status filters + pagination), create (surfaces 422 validation messages), detail with state-machine status transitions (sends `lock_version`, handles 409 by reloading). `ApiError` normalizes `{error, messages}` so failures are shown explicitly. Auth = JWT in localStorage. Component tests: list renders from a mocked API; invalid document shows the 422 message.
- [T019] Makefile complete: `run` (alias `up`), up/down/build, migrate, seed, test, lint, **smoke**, **deploy** (`kubectl apply -f k8s/`), web-build/web-test, k8s-validate, console/logs/ps. Seeds idempotent: 3 users per role (`*@bravo.test` / `password123`) + 4 sample apps spread across **received / under_review / approved / rejected** (MX+ES), created via the real pipeline + state transitions. `bin/smoke.sh` = end-to-end smoke (login → countries → list → create). **Verified: wiped-volume `make up && make seed` in 74s (<5 min); `make smoke` passes.**
- [T018] K8s manifests in `k8s/`: namespace, configmap, `secrets.example.yaml` (REPLACE_ME placeholders only), postgres (Deployment+PVC+Service), redis, api (Deployment + migrate initContainer + Service, `/up` probes), worker (sidekiq), dispatcher (runs `rake outbox:dispatch`), frontend, ingress (WS-friendly). `api`/`worker`/`dispatcher` scale by `replicas` (SKIP LOCKED + idempotent jobs). Added `lib/tasks/outbox.rake` (`outbox:dispatch` drain loop) as the dedicated dispatcher process. Validated with **kubeconform 15/15** (`make k8s-validate`); no local cluster for the literal `kubectl apply --dry-run=client`, which the README/Makefile note for cluster envs.
- [T017] Realtime via ActionCable. `ApplicationsChannel` (one shared stream `applications`); `ApplicationCable::Connection` authenticates the JWT from the `?token=` query param (browsers can't set WS headers). `Applications::Broadcaster` broadcasts the **redacted (non-PII)** view on create + status change (called from the controller). Cable adapter = redis in dev/prod (cross-process), test adapter in test; `allowed_request_origins` = `FRONTEND_ORIGINS`. Frontend `src/api/cable.ts` (`@rails/actioncable`) → list refetches on any event, detail reloads on a matching id. Live e2e: API status change → broadcast received in ~120ms, no PII.
- [T016] API changes for the SPA: enabled `rack-cors` (origins via `FRONTEND_ORIGINS`, default `http://localhost:5173`) and added `lock_version` to the serializer (non-PII; the UI needs it for optimistic-locked status changes). docker-compose `frontend` service (node:20, Vite dev server on 5173, node_modules in a named volume, no healthcheck so it doesn't gate `make up`). `make web-test` / `make web-build`.
- [T015] **Signature proven.** Added España with only `app/countries/es/` (DNI **+ NIE** mod-23 validator, different bank shape + normalizer, €50,000 review-threshold state machine) + ONE line in `Registry::NAMESPACES`. **1** file changed outside `app/countries/es/` (the registry); MX suite stayed green. The evidence is expandability/isolation (a third country is purely additive), not implementation time. ES threshold = €50,000; MX ratio limit = 30×.

## Backlog (out of scope now)
> Deferred ideas; do not build unless a task references them.
- Rate limiting, circuit breaker on provider failure, dead-letter queue, Prometheus metrics, distributed tracing.

# Plan de ejecución — Bravo Fintech MVP (MX + ES)

> Documento de trabajo. Stack: Rails 7 API · PostgreSQL · Sidekiq/Redis · JWT · Pundit · AASM · ActionCable · React/Tailwind · Docker Compose · K8s.
> Firma arquitectónica a demostrar: *"The first implementation defines the architecture; the second is configuration, not code."*

---

## 0. La decisión que define el nivel

Antes del modelo de datos, la decisión central. El requisito 3.7 ("una operación en DB genera trabajo async") + 3.9 ("múltiples workers en paralelo sin inconsistencias") tiene una respuesta canónica que conviene hacer explícita en el README:

**Transactional Outbox + `FOR UPDATE SKIP LOCKED`.**

- Un **PG trigger** sobre `credit_applications` / `state_transitions` inserta una fila en `outbox_events` dentro de la misma transacción que el cambio de estado. Atómico: no hay forma de que el estado cambie y el evento no se registre.
- Un **dispatcher** (job recurrente o LISTEN/NOTIFY) lee `outbox_events` con `SELECT ... FOR UPDATE SKIP LOCKED LIMIT N` y encola Sidekiq jobs. `SKIP LOCKED` es lo que permite correr **K dispatchers en paralelo** sin que dos tomen la misma fila — cada uno salta las filas bloqueadas por otro.
- Los jobs reciben IDs y son idempotentes (tu convención), así que un reintento nunca duplica efectos.

Esto resuelve 3.7, 3.9 y la mitad de 4.6 con un solo patrón coherente, y es la diferencia entre "metí una cola" y "diseñé el flujo de datos". El resto del documento cuelga de aquí.

---

## 1. Modelo de datos

UUID como PK en todas las tablas de dominio (fintech multi-país, evita colisiones y no filtra volumen por IDs secuenciales).

### `users`
Auth y autorización (JWT + Pundit).

| campo | tipo | notas |
|---|---|---|
| id | uuid | |
| email | citext | unique |
| password_digest | string | bcrypt |
| role | enum | `admin`, `analyst`, `operator` |
| timestamps | | |

### `credit_applications` — entidad central

| campo | tipo | notas |
|---|---|---|
| id | uuid | |
| country | enum/string | `MX`, `ES` (LIST partition key) |
| full_name | string | **PII** — encriptado (AR encryption) |
| document_type | string | `CURP`, `DNI` |
| document_number | string | **PII** — encriptado determinista (searchable) |
| document_fingerprint | string | hash (blind index) para dedupe/búsqueda |
| amount_requested | decimal(15,2) | |
| monthly_income | decimal(15,2) | **PII sensible** |
| requested_at | timestamptz | |
| status | string | manejado por AASM |
| risk_score | integer | nullable, lo llena el job async |
| flags | jsonb | `{ requires_review: true, ... }` |
| lock_version | integer | optimistic locking (lost-update guard) |
| created_at / updated_at | timestamptz | |

> Decisión PII: `document_number` con **encriptación determinista** de Rails 7 para poder hacer dedupe; `monthly_income` y `full_name` no necesitan ser buscables → encriptación no determinista. Nunca se serializan en el API salvo a roles autorizados (Pundit + serializer con scope).

### `bank_records` — Mini-ETL normalizado

Cada proveedor devuelve forma distinta; el Normalizer la colapsa a esta estructura.

| campo | tipo | notas |
|---|---|---|
| id | uuid | |
| credit_application_id | uuid | FK |
| provider | string | `MX_PROVIDER`, `ES_PROVIDER` |
| total_debt | decimal(15,2) | campo normalizado |
| credit_score | integer | normalizado (nullable según país) |
| account_status | string | normalizado |
| raw_payload | jsonb | respuesta cruda del proveedor (auditoría) |
| fetched_at | timestamptz | |

> El `raw_payload` te da auditoría y desacople: si el proveedor cambia su shape, solo tocas el Normalizer, no el dominio.

### `state_transitions` — historial de estados (AASM)

| campo | tipo | notas |
|---|---|---|
| id | uuid | |
| credit_application_id | uuid | FK |
| from_state / to_state | string | |
| actor_id | uuid | nullable (sistema vs usuario) |
| reason | string | nullable |
| metadata | jsonb | |
| created_at | timestamptz | |

### `outbox_events` — corazón del async

| campo | tipo | notas |
|---|---|---|
| id | uuid | |
| aggregate_type | string | `CreditApplication` |
| aggregate_id | uuid | |
| event_type | string | `status_changed`, `created` |
| payload | jsonb | |
| processed_at | timestamptz | null = pendiente |
| created_at | timestamptz | |

Index: `(processed_at) WHERE processed_at IS NULL` (índice parcial: el dispatcher solo escanea pendientes).

### `audit_logs` — poblado por PG trigger

| campo | tipo | notas |
|---|---|---|
| id | uuid | |
| table_name | string | |
| record_id | uuid | |
| action | string | `INSERT`/`UPDATE` |
| old_data / new_data | jsonb | |
| changed_at | timestamptz | |

> Trigger genérico en PL/pgSQL que captura el diff. Demuestra "capacidades nativas de DB" sin acoplar la auditoría a la app.

### `webhook_events` — inbound (confirmación de banco)

| campo | tipo | notas |
|---|---|---|
| id | uuid | |
| idempotency_key | string | unique — dedupe de reentregas |
| source | string | |
| payload | jsonb | |
| processed_at | timestamptz | |

### `webhook_deliveries` — outbound (notificación externa)

| campo | tipo | notas |
|---|---|---|
| id | uuid | |
| credit_application_id | uuid | FK |
| endpoint | string | |
| status | string | `pending`/`delivered`/`failed` |
| attempts | integer | |
| last_response | jsonb | |
| timestamps | | |

---

## 2. Estructura de carpetas

```
app/
  controllers/api/v1/
    auth/sessions_controller.rb          # POST /login → JWT
    credit_applications_controller.rb    # create, show, index, update_status
    webhooks_controller.rb               # POST inbound bank confirmation
  models/
    credit_application.rb                # AASM include vía country state machine
    bank_record.rb
    state_transition.rb
    outbox_event.rb
    audit_log.rb
    webhook_event.rb
    webhook_delivery.rb
    user.rb
  services/
    result.rb                            # Success/Failure (Result pattern)
    applications/
      create_application.rb              # CreateApplication.call! → Result
      update_status.rb
  countries/
    registry.rb                          # Countries.for("MX") → Country config
    base/
      validator.rb                       # interfaz
      bank_provider.rb
      normalizer.rb
      state_machine.rb
    mx/
      validator.rb                       # CURP + ratio ingreso/monto
      bank_provider.rb                   # simula proveedor MX
      normalizer.rb                      # shape MX → interno
      state_machine.rb                   # estados MX
    es/
      validator.rb                       # DNI (checksum) + umbral revisión
      bank_provider.rb
      normalizer.rb
      state_machine.rb
  policies/
    application_policy.rb                # Pundit: admin/analyst/operator
    credit_application_policy.rb
  serializers/
    credit_application_serializer.rb     # scope-aware (oculta PII según rol)
  jobs/
    outbox_dispatch_job.rb               # recurrente: SKIP LOCKED → encola
    risk_evaluation_job.rb               # idempotente
    audit_notification_job.rb
    webhook_delivery_job.rb              # outbound con retries
  channels/
    applications_channel.rb              # ActionCable realtime
  lib/
    structured_logger.rb                 # JSON: event:, country:, application_id:

db/
  migrate/                               # incluye triggers (outbox + audit)
  functions/                             # PL/pgSQL versionado

k8s/
  backend-deployment.yaml  worker-deployment.yaml  dispatcher-deployment.yaml
  frontend-deployment.yaml  postgres.yaml  redis.yaml
  services.yaml  ingress.yaml  configmap.yaml  secrets.example.yaml

frontend/                                # React + Tailwind + ActionCable client
Makefile  docker-compose.yml  README.md
```

> El punto donde se ve tu firma: agregar Colombia = crear `countries/co/` con 4 clases + registrar en `registry.rb`. Cero cambios en controllers, services, jobs o modelos. Esto va literal en el README como prueba.

### El contrato de país (Registry)

```ruby
# countries/registry.rb
Countries.for("MX") # => Country.new(
#   validator:     MX::Validator,
#   bank_provider: MX::BankProvider,
#   normalizer:    MX::Normalizer,
#   state_machine: MX::StateMachine
# )
```

`CreateApplication` nunca menciona "MX" ni "ES". Pide `Countries.for(params[:country])` y delega. Eso es "configuración, no código".

---

## 3. Reglas por país (concreto)

No bastan strings: validación *razonablemente válida* significa algoritmos reales, y eso se nota.

**MX**
- `CURP`: 18 chars, regex de formato + dígito verificador. Documento requerido.
- Regla de negocio: ratio `amount_requested / monthly_income`. Si supera N (ej. 30x ingreso mensual) → rechazo o revisión.
- Bank provider MX devuelve, p.ej., `{ deuda_total, buro_score, estatus_cuenta }`.

**ES**
- `DNI`: 8 dígitos + letra. **Validar la letra con el algoritmo mod 23** (la letra es determinística sobre el número). Esto demuestra "verificación del documento" de verdad.
- Regla de negocio: si `amount_requested > umbral` (definido por ti, ej. 50.000 €) → `flags.requires_review = true`, estado va a `under_review` en vez de auto-aprobar.
- Bank provider ES devuelve shape distinto, p.ej. `{ total_liabilities, scoring, account_state }` → el Normalizer ES lo mapea a `total_debt / credit_score / account_status`.

> Mismo dato interno (`total_debt`), dos shapes externos: ese es el mini-ETL en acción y la justificación del Normalizer por país.

---

## 4. Acceptance Criteria por feature

Mapeados a los requisitos del PDF. TDD: cada AC es un test antes del código.

**F1 — Auth (JWT) + Authz (Pundit)** · req 4.2
- POST `/api/v1/login` con credenciales válidas → 200 + JWT.
- Endpoints de aplicaciones sin token → 401.
- `operator` puede crear y ver; `analyst` puede cambiar estado; `admin` todo. Violación → 403.
- El serializer oculta `document_number`/`monthly_income` a roles no autorizados.

**F2 — Crear solicitud** · req 3.1, 3.2, 3.3
- POST con país no soportado → 422 con mensaje claro.
- Documento inválido para el país (DNI con letra incorrecta, CURP mal formado) → 422.
- Creación válida → 201, estado inicial correcto, `bank_record` poblado vía provider+normalizer.
- La creación dispara lógica async (no bloquea la respuesta): se inserta `outbox_event`.
- MX: ratio excedido → estado/flag correcto. ES: monto > umbral → `requires_review`.

**F3 — Consultar solicitud** · req 3.5
- GET `/applications/:id` existente → 200 con datos completos (respetando scope PII).
- ID inexistente → 404.
- Segunda lectura del mismo ID → servida desde caché (ver F9).

**F4 — Listar con filtros** · req 3.6
- GET `/applications?country=MX` → solo MX.
- Filtros combinables: `status`, `from`/`to` (rango fechas).
- Paginación presente (no devolver millones de filas).
- Sin N+1 (eager-load `bank_record`); verificable con `bullet` o assert de queries.

**F5 — Actualizar estado (state machine)** · req 3.4
- Transición válida según AASM del país → 200, se registra `state_transition`.
- Transición inválida (guard AASM) → 422, estado sin cambiar.
- Update concurrente con `lock_version` desfasado → 409 (optimistic lock).
- La transición inserta `outbox_event` (dispara notificaciones/auditoría).

**F6 — Async vía outbox + PG trigger** · req 3.7
- Cambiar estado inserta fila en `outbox_events` en la **misma transacción** (test: rollback del cambio → no hay evento).
- `OutboxDispatchJob` toma pendientes con `SKIP LOCKED` y encola el job correcto.
- `RiskEvaluationJob` es idempotente: correrlo dos veces con el mismo ID no duplica efectos.

**F7 — Concurrencia / paralelo** · req 3.9
- Dos dispatchers simultáneos no procesan el mismo `outbox_event` (test con `SKIP LOCKED`).
- Escalar workers = subir réplicas (documentado en K8s, no requiere cambio de código).

**F8 — Webhooks** · req 3.8
- Outbound: cambio de estado → `WebhookDeliveryJob` POSTea a endpoint externo simulado, con firma HMAC y reintentos; registra `webhook_delivery`.
- Inbound: POST `/webhooks/bank` con `idempotency_key` repetido → procesado una sola vez (dedupe).
- El webhook inbound actualiza la solicitud (confirmación de datos / cambio de estado).

**F9 — Caching** · req 4.7
- Lectura individual cacheada con key versionada por `updated_at`.
- Update invalida automáticamente (la key cambia con `updated_at`).
- Catálogo de config de país cacheado con TTL largo.

**F10 — Realtime frontend** · req 3.10, 5
- Crear/cambiar estado emite por ActionCable; la lista en React se actualiza sin refresh.
- Frontend: crear, listar, ver detalle, cambiar estado, manejo de errores visible.

**F11 — Observabilidad** · req 4.3
- Logs JSON estructurados con `event:`, `country:`, `application_id:` en cada paso del flujo async.
- Errores manejados explícitamente (Result pattern, sin excepciones como flow control).

---

## 5. Orden de ejecución — 3 días

Tu regla: Foundation & API antes de Client; enablers backend antes de web. El riesgo real es dejar README + frontend para el final, así que **el README se escribe incremental** (captura cada decisión al tomarla, no al final).

### Día 1 — Fundación y API síncrona
1. `docker-compose.yml` + Rails skeleton + Postgres + Redis arrancando (`make up` < 5 min). *Esto primero: si no arranca, nada importa.*
2. Migraciones: `users`, `credit_applications`, `bank_records`, `state_transitions`. UUIDs, índices base, encriptación PII.
3. JWT auth + Pundit (F1).
4. `Countries::Registry` + clases **solo de MX** (validator/provider/normalizer). El segundo país viene después a propósito — para *probar* que el primero definió la arquitectura.
5. `Result`, `CreateApplication` (F2), GET (F3), index con filtros (F4). Tests verdes.
6. README: secciones Quick start, Assumptions, Data model (empieza el ERD).

**Fin del día 1: API CRUD funcional con un país, autenticada, testeada.**

### Día 2 — Async, estados, segundo país
7. AASM + `update_status` + `state_transitions` (F5). State machine MX.
8. **PG triggers**: outbox + audit_log (migración con PL/pgSQL). `OutboxDispatchJob` con `SKIP LOCKED` (F6, F7).
9. `RiskEvaluationJob` idempotente. Structured logger (F11).
10. Webhooks inbound + outbound (F8).
11. Caching (F9).
12. **Agregar ES.** La prueba de la abstracción no es cuánto tardas, sino el **aislamiento y la expandibilidad**: agregar el segundo país debe ser *puramente aditivo* — crear `app/countries/es/` (validador DNI, proveedor con otra forma, normalizer, state machine) + **una línea** en el registry, sin tocar controllers/services/jobs/models y sin riesgo de perturbar el país ya en producción. Si te obliga a editar código compartido, la abstracción del día 1 falló y hay que ajustarla. Esa propiedad — *un tercer país = una carpeta + una línea* — es la evidencia de Staff que va al README (no el tiempo de implementación).
13. README: Technical decisions, Security, Concurrency, Caching, Webhooks.

**Fin del día 2: sistema completo backend, dos países, async sólido.**

### Día 3 — Frontend, infra, README final
14. React + Tailwind: crear / listar / detalle / cambiar estado, manejo de errores (F10, req 5).
15. ActionCable cliente: realtime en la lista.
16. K8s manifests (backend, worker, dispatcher, frontend, pg, redis, services, ingress, configmap). Sin deploy real.
17. Makefile (`run`, `test`, `migrate`, `seed`, `deploy`).
18. **README: análisis de escalabilidad** (la sección que gana nivel — ver §6) + diagrama de arquitectura + "qué haría con más tiempo".
19. Seeds + smoke test end-to-end. Repo público limpio (sin secrets, `secrets.example.yaml`).

> Si el tiempo aprieta el día 3: el frontend puede ser deliberadamente simple (es explícito en el PDF: "diseño sencillo"). **No sacrifiques el README de escalabilidad** — ahí es donde te miden como Staff, no en el CSS.

---

## 6. README — esqueleto Staff (lo que te sube de nivel)

Sugerencia: README en inglés (repo público internacional, fintech multipaís). Estructura:

1. **Overview + diagrama de arquitectura** (un ASCII/mermaid del flujo: API → outbox → dispatcher → Sidekiq → webhook/cable).
2. **Quick start** — `make up && make seed`, < 5 min. Probado en limpio.
3. **Assumptions** — qué simulaste (proveedores bancarios, endpoint webhook externo), qué dejaste fuera a propósito.
4. **Data model** — ERD + por qué UUID, por qué jsonb en `raw_payload`, por qué encriptación determinista vs no.
5. **Technical decisions** — cada una con *tradeoff*, no solo "usé X". Ej: "Outbox sobre publicar-a-cola-directo porque garantiza atomicidad estado↔evento; el costo es latencia de polling, mitigable con LISTEN/NOTIFY."
6. **Security** — PII encriptada, JWT, Pundit por rol, serializers scope-aware, sin datos bancarios en respuestas, HMAC en webhooks.
7. **Scalability (millones de solicitudes)** — la sección estrella:
   - **Índices**: compuesto `(country, status, created_at)` para el listado crítico; `(document_fingerprint)` unique para dedupe; parcial `WHERE processed_at IS NULL` en outbox; BRIN en `created_at` para rangos de fecha en tablas enormes.
   - **Particionamiento**: declarativo por `LIST (country)` (cada país aislado, pruning automático en queries filtradas por país) y sub-partición `RANGE (created_at)` mensual. Tradeoff vs hash. `pg_partman` para partición rodante.
   - **Consultas críticas**: el listado país+estado+fecha → cubierto por índice compuesto + partition pruning. Fetch por ID → PK + caché. Evitar N+1 con eager-load y `exists?`.
   - **Cuellos de botella**: updates calientes de estado → `SKIP LOCKED` + optimistic locking; saturación de cola → colas Sidekiq por prioridad (risk vs audit vs webhook) y réplicas independientes.
   - **Archivado**: aplicaciones en estado terminal > N meses → partición fría / tabla archive / export a S3+Parquet; particionamiento hace el drop de particiones viejas O(1).
8. **Concurrency strategy** — outbox + `SKIP LOCKED` (N dispatchers), jobs idempotentes (IDs, no objetos), optimistic locking, AASM guards. Escalado = réplicas en K8s.
9. **Caching strategy** — qué (lecturas individuales, config de país), por qué, invalidación por key versionada (`updated_at` en la key = invalidación automática, sin busting manual).
10. **Webhooks** — inbound idempotente (dedupe por key), outbound con retries + firma + log de entregas.
11. **How to add a country** — los 4 archivos + 1 línea de registro. *Tu firma, hecha prueba.*
12. **Testing strategy** — TDD, qué cubriste, cómo correrlo.
13. **What I'd do with more time** — honestidad de Staff: rate limiting, circuit breaker ante caída de proveedor, dead-letter queue, métricas Prometheus, tracing distribuido.

---

## 7. Trampas a evitar

- **No sobre-ingenierizar** (tu propia convención): no necesitas event sourcing ni CQRS; el outbox es suficiente y defendible. Si lo agregas, justifícalo o resta puntos.
- **Idempotencia real, no decorativa**: el `RiskEvaluationJob` debe chequear estado antes de actuar, no solo "asumir" que corre una vez.
- **No filtrar PII en logs**: el structured logger nunca debe loguear `document_number` ni `monthly_income` en claro. Loguea `application_id`, no el contenido.
- **El `make up` tiene que funcionar en limpio**: pruébalo en un clon fresco antes de entregar. Un evaluador que no puede levantar en 5 min ya te bajó de nivel en req 4.4.
- **Migraciones con triggers reversibles**: `up`/`down` del trigger en la migración, no SQL suelto sin rollback.

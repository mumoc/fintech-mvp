#!/usr/bin/env bash
# End-to-end smoke test against the running stack. Assumes `make up && make seed`.
set -euo pipefail

BASE="${BASE_URL:-http://localhost:3000}"
pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ SMOKE FAIL: $1"; exit 1; }

echo "Smoke test against ${BASE}"

# 1. API healthy
for _ in $(seq 1 30); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' "${BASE}/up")" = "200" ] && break
  sleep 2
done
[ "$(curl -s -o /dev/null -w '%{http_code}' "${BASE}/up")" = "200" ] || fail "GET /up is not 200"
pass "api healthy"

# 2. Login (seeded user)
TOKEN=$(curl -s -X POST "${BASE}/api/v1/login" \
  -H 'content-type: application/json' \
  -d '{"email":"operator@bravo.test","password":"password123"}' \
  | sed -E 's/.*"token":"([^"]+)".*/\1/')
[ "${#TOKEN}" -gt 20 ] || fail "login did not return a token (did you run 'make seed'?)"
AUTH="authorization: Bearer ${TOKEN}"
pass "login (operator@bravo.test)"

# 3. Country catalog
COUNTRIES=$(curl -s "${BASE}/api/v1/countries" -H "${AUTH}")
echo "${COUNTRIES}" | grep -q '"MX"' || fail "country catalog missing MX"
echo "${COUNTRIES}" | grep -q '"ES"' || fail "country catalog missing ES"
pass "countries catalog (MX, ES)"

# 4. List seeded applications
LIST=$(curl -s "${BASE}/api/v1/credit_applications?per_page=1" -H "${AUTH}")
TOTAL=$(echo "${LIST}" | sed -E 's/.*"total":([0-9]+).*/\1/')
[ "${TOTAL:-0}" -ge 1 ] || fail "no seeded applications found (total=${TOTAL:-0})"
pass "list (${TOTAL} applications)"

# 5. Create (idempotent: 201 first run, 422 duplicate on re-run — both prove the pipeline)
CODE=$(curl -s -o /dev/null -w '%{http_code}' -X POST "${BASE}/api/v1/credit_applications" \
  -H "${AUTH}" -H 'content-type: application/json' \
  -d '{"credit_application":{"country":"ES","full_name":"Smoke Test","document_number":"X0000000T","amount_requested":10000,"monthly_income":3000}}')
case "${CODE}" in
  201) pass "create (201)" ;;
  422) pass "create endpoint OK (422 — already created by a prior smoke)" ;;
  *) fail "create returned ${CODE}" ;;
esac

echo "SMOKE PASS"

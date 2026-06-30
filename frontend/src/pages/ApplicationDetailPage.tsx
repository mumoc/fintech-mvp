import { useCallback, useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { getApplication, updateStatus } from "../api/applications";
import { subscribeToApplications } from "../api/cable";
import type { Application } from "../api/types";
import { ApiError } from "../api/client";
import { ErrorBanner } from "../components/ErrorBanner";

// Events available from each status (mirrors the backend AASM graph).
const EVENTS_BY_STATUS: Record<string, string[]> = {
  received: ["start_review", "approve", "reject", "cancel"],
  under_review: ["approve", "reject", "cancel"],
  approved: [],
  rejected: [],
  cancelled: [],
};

export function ApplicationDetailPage() {
  const { id = "" } = useParams();
  const [app, setApp] = useState<Application | null>(null);
  const [error, setError] = useState<ApiError | null>(null);
  const [busy, setBusy] = useState(false);

  const load = useCallback(() => {
    setError(null);
    getApplication(id)
      .then(setApp)
      .catch((e) => setError(e as ApiError));
  }, [id]);

  useEffect(load, [load]);

  // Realtime: reload this application when it changes elsewhere (re-fetches the
  // role-appropriate view, including PII for authorized users).
  useEffect(
    () =>
      subscribeToApplications((event) => {
        if (event.application.id === id) load();
      }),
    [id, load],
  );

  async function fire(event: string) {
    if (!app) return;
    setBusy(true);
    setError(null);
    try {
      const updated = await updateStatus(app.id, event, app.lock_version);
      setApp(updated);
    } catch (e) {
      setError(e as ApiError);
      // On a stale-lock conflict, reload to pick up the latest version.
      if ((e as ApiError).status === 409) load();
    } finally {
      setBusy(false);
    }
  }

  if (error && !app) return <ErrorBanner error={error} />;
  if (!app) return <p className="text-sm text-gray-500">Loading…</p>;

  const events = EVENTS_BY_STATUS[app.status] ?? [];

  return (
    <div className="max-w-2xl">
      <Link to="/applications" className="text-sm text-blue-600 hover:underline">
        ← Back to applications
      </Link>

      <h1 className="mb-1 mt-2 text-xl font-bold">
        {app.country} · {app.document_type}
      </h1>
      <p className="mb-4">
        <span className="rounded bg-gray-100 px-2 py-1 text-sm">{app.status}</span>
      </p>

      <ErrorBanner error={error} />

      <dl className="grid grid-cols-2 gap-3 rounded-lg border bg-white p-4 text-sm">
        <Field label="Amount requested" value={app.amount_requested} />
        <Field label="Risk score" value={app.risk_score ?? "—"} />
        {app.full_name !== undefined && <Field label="Full name" value={app.full_name} />}
        {app.document_number !== undefined && (
          <Field label="Document" value={app.document_number} />
        )}
        {app.monthly_income !== undefined && (
          <Field label="Monthly income" value={app.monthly_income} />
        )}
        <Field label="Flags" value={JSON.stringify(app.flags)} />
        {app.bank_record && (
          <>
            <Field label="Bank provider" value={app.bank_record.provider} />
            <Field label="Total debt" value={app.bank_record.total_debt ?? "—"} />
            <Field label="Credit score" value={app.bank_record.credit_score ?? "—"} />
            <Field label="Account status" value={app.bank_record.account_status ?? "—"} />
          </>
        )}
      </dl>

      <div className="mt-4">
        <h2 className="mb-2 text-sm font-semibold text-gray-700">Change status</h2>
        {events.length === 0 ? (
          <p className="text-sm text-gray-500">No further transitions from “{app.status}”.</p>
        ) : (
          <div className="flex flex-wrap gap-2">
            {events.map((event) => (
              <button
                key={event}
                onClick={() => fire(event)}
                disabled={busy}
                className="rounded border px-3 py-2 text-sm hover:bg-gray-100 disabled:opacity-50"
              >
                {event.replace(/_/g, " ")}
              </button>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

function Field({ label, value }: { label: string; value: string | number }) {
  return (
    <div>
      <dt className="text-gray-500">{label}</dt>
      <dd className="font-medium">{value}</dd>
    </div>
  );
}

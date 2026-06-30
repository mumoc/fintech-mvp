import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { listApplications } from "../api/applications";
import { subscribeToApplications } from "../api/cable";
import type { Application, Page } from "../api/types";
import { ApiError } from "../api/client";
import { ErrorBanner } from "../components/ErrorBanner";

const STATUSES = ["received", "under_review", "approved", "rejected", "cancelled"];

export function ApplicationsPage() {
  const [country, setCountry] = useState("");
  const [status, setStatus] = useState("");
  const [page, setPage] = useState(1);
  const [result, setResult] = useState<Page<Application> | null>(null);
  const [error, setError] = useState<ApiError | null>(null);
  const [loading, setLoading] = useState(false);
  const [reloadKey, setReloadKey] = useState(0);

  useEffect(() => {
    let active = true;
    setLoading(true);
    setError(null);
    listApplications({ country, status, page, per_page: 10 })
      .then((data) => active && setResult(data))
      .catch((e) => active && setError(e as ApiError))
      .finally(() => active && setLoading(false));
    return () => {
      active = false;
    };
  }, [country, status, page, reloadKey]);

  // Realtime: refetch the current page when an application is created/changed.
  useEffect(() => subscribeToApplications(() => setReloadKey((k) => k + 1)), []);

  return (
    <div>
      <div className="mb-4 flex items-center justify-between">
        <h1 className="text-xl font-bold">Credit applications</h1>
        <Link to="/applications/new" className="rounded bg-gray-900 px-3 py-2 text-sm text-white">
          New application
        </Link>
      </div>

      <div className="mb-4 flex gap-3">
        <select
          aria-label="Filter by country"
          value={country}
          onChange={(e) => {
            setPage(1);
            setCountry(e.target.value);
          }}
          className="rounded border px-3 py-2 text-sm"
        >
          <option value="">All countries</option>
          <option value="MX">MX</option>
          <option value="ES">ES</option>
        </select>
        <select
          aria-label="Filter by status"
          value={status}
          onChange={(e) => {
            setPage(1);
            setStatus(e.target.value);
          }}
          className="rounded border px-3 py-2 text-sm"
        >
          <option value="">All statuses</option>
          {STATUSES.map((s) => (
            <option key={s} value={s}>
              {s}
            </option>
          ))}
        </select>
      </div>

      <ErrorBanner error={error} />

      {loading && <p className="text-sm text-gray-500">Loading…</p>}

      {result && (
        <>
          <table className="w-full border-collapse text-sm">
            <thead>
              <tr className="border-b text-left text-gray-500">
                <th className="py-2">Country</th>
                <th className="py-2">Document</th>
                <th className="py-2">Amount</th>
                <th className="py-2">Status</th>
                <th className="py-2">Risk</th>
                <th className="py-2"></th>
              </tr>
            </thead>
            <tbody>
              {result.data.map((app) => (
                <tr key={app.id} className="border-b">
                  <td className="py-2">{app.country}</td>
                  <td className="py-2">{app.document_type}</td>
                  <td className="py-2">{app.amount_requested}</td>
                  <td className="py-2">
                    <span className="rounded bg-gray-100 px-2 py-1 text-xs">{app.status}</span>
                  </td>
                  <td className="py-2">{app.risk_score ?? "—"}</td>
                  <td className="py-2 text-right">
                    <Link to={`/applications/${app.id}`} className="text-blue-600 hover:underline">
                      View
                    </Link>
                  </td>
                </tr>
              ))}
              {result.data.length === 0 && (
                <tr>
                  <td colSpan={6} className="py-6 text-center text-gray-500">
                    No applications match these filters.
                  </td>
                </tr>
              )}
            </tbody>
          </table>

          <div className="mt-4 flex items-center justify-between text-sm text-gray-600">
            <span>
              Page {result.meta.page} of {result.meta.total_pages || 1} · {result.meta.total} total
            </span>
            <div className="flex gap-2">
              <button
                onClick={() => setPage((p) => Math.max(1, p - 1))}
                disabled={result.meta.page <= 1}
                className="rounded border px-3 py-1 disabled:opacity-40"
              >
                Previous
              </button>
              <button
                onClick={() => setPage((p) => p + 1)}
                disabled={result.meta.page >= result.meta.total_pages}
                className="rounded border px-3 py-1 disabled:opacity-40"
              >
                Next
              </button>
            </div>
          </div>
        </>
      )}
    </div>
  );
}

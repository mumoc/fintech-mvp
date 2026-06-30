import { useEffect, useState, type FormEvent } from "react";
import { useNavigate } from "react-router-dom";
import { createApplication, listCountries } from "../api/applications";
import type { Country, NewApplication } from "../api/types";
import { ApiError } from "../api/client";
import { ErrorBanner } from "../components/ErrorBanner";

const EMPTY: NewApplication = {
  country: "MX",
  full_name: "",
  document_number: "",
  amount_requested: "",
  monthly_income: "",
};

export function NewApplicationPage() {
  const navigate = useNavigate();
  const [form, setForm] = useState<NewApplication>(EMPTY);
  const [countries, setCountries] = useState<Country[]>([]);
  const [error, setError] = useState<ApiError | null>(null);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    listCountries()
      .then((res) => setCountries(res.data))
      .catch(() => setCountries([{ code: "MX", document_type: "CURP" }]));
  }, []);

  function update(field: keyof NewApplication, value: string) {
    setForm((prev) => ({ ...prev, [field]: value }));
  }

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      const created = await createApplication(form);
      navigate(`/applications/${created.id}`);
    } catch (e) {
      setError(e as ApiError);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="max-w-lg">
      <h1 className="mb-4 text-xl font-bold">New credit application</h1>
      <ErrorBanner error={error} />

      <form onSubmit={onSubmit} className="space-y-4 rounded-lg border bg-white p-6">
        <label className="block text-sm">
          <span className="mb-1 block text-gray-700">Country</span>
          <select
            value={form.country}
            onChange={(e) => update("country", e.target.value)}
            className="w-full rounded border px-3 py-2"
          >
            {(countries.length ? countries : [{ code: "MX", document_type: "CURP" }]).map((c) => (
              <option key={c.code} value={c.code}>
                {c.code} ({c.document_type})
              </option>
            ))}
          </select>
        </label>

        <label className="block text-sm">
          <span className="mb-1 block text-gray-700">Full name</span>
          <input
            value={form.full_name}
            onChange={(e) => update("full_name", e.target.value)}
            className="w-full rounded border px-3 py-2"
          />
        </label>

        <label className="block text-sm">
          <span className="mb-1 block text-gray-700">Document number</span>
          <input
            value={form.document_number}
            onChange={(e) => update("document_number", e.target.value)}
            placeholder="MX CURP or ES DNI"
            className="w-full rounded border px-3 py-2"
          />
        </label>

        <div className="flex gap-4">
          <label className="block flex-1 text-sm">
            <span className="mb-1 block text-gray-700">Amount requested</span>
            <input
              type="number"
              value={form.amount_requested}
              onChange={(e) => update("amount_requested", e.target.value)}
              className="w-full rounded border px-3 py-2"
            />
          </label>
          <label className="block flex-1 text-sm">
            <span className="mb-1 block text-gray-700">Monthly income</span>
            <input
              type="number"
              value={form.monthly_income}
              onChange={(e) => update("monthly_income", e.target.value)}
              className="w-full rounded border px-3 py-2"
            />
          </label>
        </div>

        <button
          type="submit"
          disabled={submitting}
          className="rounded bg-gray-900 px-4 py-2 text-white disabled:opacity-50"
        >
          {submitting ? "Creating…" : "Create application"}
        </button>
      </form>
    </div>
  );
}

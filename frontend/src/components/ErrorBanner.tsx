import type { ApiError } from "../api/client";

export function ErrorBanner({ error }: { error: ApiError | null }) {
  if (!error) return null;

  return (
    <div role="alert" className="mb-4 rounded border border-red-300 bg-red-50 p-3 text-sm text-red-800">
      <p className="font-semibold capitalize">{error.code.replace(/_/g, " ")}</p>
      <ul className="mt-1 list-inside list-disc">
        {error.messages.map((message, index) => (
          <li key={index}>{message}</li>
        ))}
      </ul>
    </div>
  );
}

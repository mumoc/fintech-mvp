// Reflects flags.bank_confirmed, set asynchronously by the inbound bank webhook.
// The badge flips from "Pending" to "Confirmed" in realtime over ActionCable
// (no page refresh) when the bank's callback arrives.
export function BankConfirmationBadge({ confirmed }: { confirmed: boolean }) {
  if (confirmed) {
    return (
      <span
        aria-label="Bank confirmed"
        className="inline-flex items-center gap-1 rounded-full border border-green-200 bg-green-50 px-2 py-0.5 text-xs font-semibold text-green-700"
      >
        <span aria-hidden>✓</span>
        Confirmed
      </span>
    );
  }

  return (
    <span
      aria-label="Bank confirmation pending"
      className="inline-flex items-center gap-1 rounded-full border border-gray-200 bg-gray-50 px-2 py-0.5 text-xs font-semibold text-gray-500"
    >
      <span aria-hidden>⏳</span>
      Pending
    </span>
  );
}

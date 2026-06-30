const RISK_HELP =
  "Risk score ranges from 0 to 100. Lower is better; higher means riskier based on bank credit score and requested amount vs monthly income.";

export function RiskHelp() {
  return (
    <span
      className="group relative ml-1 inline-flex h-4 w-4 items-center justify-center rounded-full border border-gray-300 text-[10px] font-semibold text-gray-500 focus-within:border-gray-500"
    >
      <button
        type="button"
        aria-label={RISK_HELP}
        className="h-full w-full rounded-full leading-none outline-none focus:ring-2 focus:ring-gray-400"
      >
        ?
      </button>
      <span className="pointer-events-none absolute left-1/2 top-6 z-20 hidden w-64 -translate-x-1/2 rounded-md bg-gray-900 px-3 py-2 text-left text-xs font-normal leading-relaxed text-white shadow-lg group-focus-within:block group-hover:block">
        {RISK_HELP}
      </span>
    </span>
  );
}

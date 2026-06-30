type RiskLevel = "low" | "medium" | "high";

function riskLevel(score: number): RiskLevel {
  if (score <= 30) return "low";
  if (score <= 70) return "medium";
  return "high";
}

const STYLES: Record<RiskLevel, { label: string; className: string }> = {
  low: {
    label: "Low",
    className: "border-green-200 bg-green-50 text-green-700",
  },
  medium: {
    label: "Medium",
    className: "border-yellow-200 bg-yellow-50 text-yellow-700",
  },
  high: {
    label: "High",
    className: "border-red-200 bg-red-50 text-red-700",
  },
};

export function RiskBadge({ score }: { score: number | null }) {
  if (score === null) return <span className="text-gray-400">—</span>;

  const level = riskLevel(score);
  const style = STYLES[level];

  return (
    <span
      aria-label={`${style.label} risk, score ${score} out of 100`}
      className={`inline-flex items-center gap-1 rounded-full border px-2 py-0.5 text-xs font-semibold ${style.className}`}
    >
      <span>{score}</span>
      <span className="hidden sm:inline">{style.label}</span>
    </span>
  );
}

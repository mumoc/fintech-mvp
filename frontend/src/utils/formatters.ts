const CURRENCY_BY_COUNTRY: Record<string, string> = {
  ES: "EUR",
  MX: "MXN",
};

export function formatMoney(value: string | number | null | undefined, country: string): string {
  if (value === null || value === undefined || value === "") return "—";

  const amount = typeof value === "number" ? value : Number(value);
  if (Number.isNaN(amount)) return String(value);

  const currency = CURRENCY_BY_COUNTRY[country.toUpperCase()];
  if (!currency) return amount.toLocaleString("en-US", { maximumFractionDigits: 2 });

  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency,
    currencyDisplay: "symbol",
  }).format(amount);
}

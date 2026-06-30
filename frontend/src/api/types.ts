export interface BankRecord {
  provider: string;
  total_debt: string | null;
  credit_score: number | null;
  account_status: string | null;
}

export interface Application {
  id: string;
  country: string;
  document_type: string;
  amount_requested: string;
  status: string;
  risk_score: number | null;
  flags: Record<string, unknown>;
  lock_version: number;
  requested_at: string | null;
  created_at: string;
  updated_at: string;
  bank_record: BankRecord | null;
  // Present only for PII-authorized roles (analyst/admin):
  full_name?: string;
  document_number?: string;
  monthly_income?: string;
}

export interface Page<T> {
  data: T[];
  meta: { page: number; per_page: number; total: number; total_pages: number };
}

export interface Country {
  code: string;
  document_type: string;
}

export interface ApplicationFilters {
  country?: string;
  status?: string;
  page?: number;
  per_page?: number;
}

export interface NewApplication {
  country: string;
  full_name: string;
  document_number: string;
  amount_requested: string;
  monthly_income: string;
}

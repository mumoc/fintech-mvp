import { request, setToken } from "./client";
import type {
  Application,
  ApplicationFilters,
  Country,
  NewApplication,
  Page,
} from "./types";

export async function login(email: string, password: string): Promise<{ role: string }> {
  const result = await request<{ token: string; role: string }>("/login", {
    method: "POST",
    auth: false,
    body: { email, password },
  });
  setToken(result.token);
  return { role: result.role };
}

export function listCountries(): Promise<{ data: Country[] }> {
  return request<{ data: Country[] }>("/countries");
}

export function listApplications(filters: ApplicationFilters = {}): Promise<Page<Application>> {
  const params = new URLSearchParams();
  if (filters.country) params.set("country", filters.country);
  if (filters.status) params.set("status", filters.status);
  if (filters.page) params.set("page", String(filters.page));
  if (filters.per_page) params.set("per_page", String(filters.per_page));
  const query = params.toString();
  return request<Page<Application>>(`/credit_applications${query ? `?${query}` : ""}`);
}

export function getApplication(id: string): Promise<Application> {
  return request<Application>(`/credit_applications/${id}`);
}

export function createApplication(attrs: NewApplication): Promise<Application> {
  return request<Application>("/credit_applications", {
    method: "POST",
    body: { credit_application: attrs },
  });
}

export function updateStatus(
  id: string,
  event: string,
  lockVersion: number,
): Promise<Application> {
  return request<Application>(`/credit_applications/${id}/status`, {
    method: "PATCH",
    body: { credit_application: { event, lock_version: lockVersion } },
  });
}

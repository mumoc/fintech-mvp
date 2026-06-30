const BASE_URL =
  (import.meta.env.VITE_API_BASE_URL as string | undefined) ?? "http://localhost:3000/api/v1";

const TOKEN_KEY = "bravo.token";

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token: string | null): void {
  if (token) localStorage.setItem(TOKEN_KEY, token);
  else localStorage.removeItem(TOKEN_KEY);
}

// Normalized API error: carries the HTTP status, the machine-readable `code`,
// and human-readable `messages` surfaced by the Rails API.
export class ApiError extends Error {
  status: number;
  code: string;
  messages: string[];

  constructor(status: number, code: string, messages: string[]) {
    super(messages[0] ?? code);
    this.name = "ApiError";
    this.status = status;
    this.code = code;
    this.messages = messages;
  }
}

interface RequestOptions {
  method?: string;
  body?: unknown;
  auth?: boolean;
}

export async function request<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const { method = "GET", body, auth = true } = options;
  const headers: Record<string, string> = { "Content-Type": "application/json" };

  if (auth) {
    const token = getToken();
    if (token) headers["Authorization"] = `Bearer ${token}`;
  }

  let response: Response;
  try {
    response = await fetch(`${BASE_URL}${path}`, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch {
    throw new ApiError(0, "network_error", ["Network error — is the API running?"]);
  }

  if (response.status === 204) return undefined as T;

  const text = await response.text();
  const payload = text ? JSON.parse(text) : {};

  if (!response.ok) {
    const code = typeof payload.error === "string" ? payload.error : `http_${response.status}`;
    const messages: string[] =
      Array.isArray(payload.messages) && payload.messages.length > 0
        ? payload.messages
        : [humanizeStatus(response.status, code)];
    throw new ApiError(response.status, code, messages);
  }

  return payload as T;
}

function humanizeStatus(status: number, code: string): string {
  if (status === 401) return "Not authenticated.";
  if (status === 403) return "You are not allowed to do that.";
  if (status === 404) return "Not found.";
  if (status === 409) return "This record changed since you loaded it — reload and retry.";
  return code.replace(/_/g, " ");
}

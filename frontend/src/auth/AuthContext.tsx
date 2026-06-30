import { createContext, useContext, useMemo, useState, type ReactNode } from "react";
import { getToken, setToken } from "../api/client";
import { login as apiLogin } from "../api/applications";

interface AuthState {
  isAuthenticated: boolean;
  role: string | null;
  signIn: (email: string, password: string) => Promise<void>;
  signOut: () => void;
}

const AuthContext = createContext<AuthState | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [token, setTokenState] = useState<string | null>(getToken());
  const [role, setRole] = useState<string | null>(localStorage.getItem("bravo.role"));

  const value = useMemo<AuthState>(
    () => ({
      isAuthenticated: Boolean(token),
      role,
      signIn: async (email, password) => {
        const { role: newRole } = await apiLogin(email, password);
        setTokenState(getToken());
        setRole(newRole);
        localStorage.setItem("bravo.role", newRole);
      },
      signOut: () => {
        setToken(null);
        localStorage.removeItem("bravo.role");
        setTokenState(null);
        setRole(null);
      },
    }),
    [token, role],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within an AuthProvider");
  return ctx;
}

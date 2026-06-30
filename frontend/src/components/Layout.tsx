import { Link, Outlet, useNavigate } from "react-router-dom";
import { useAuth } from "../auth/AuthContext";

export function Layout() {
  const { role, signOut } = useAuth();
  const navigate = useNavigate();

  return (
    <div className="min-h-screen bg-gray-50 text-gray-900">
      <header className="border-b bg-white">
        <div className="mx-auto flex max-w-5xl items-center justify-between px-4 py-3">
          <div className="flex items-center gap-6">
            <Link to="/applications" className="text-lg font-bold">
              Bravo Fintech
            </Link>
            <Link to="/applications" className="text-sm text-gray-600 hover:text-gray-900">
              Applications
            </Link>
            <Link to="/applications/new" className="text-sm text-gray-600 hover:text-gray-900">
              New
            </Link>
          </div>
          <div className="flex items-center gap-3 text-sm">
            {role && <span className="rounded bg-gray-100 px-2 py-1 text-gray-600">{role}</span>}
            <button
              onClick={() => {
                signOut();
                navigate("/login");
              }}
              className="text-gray-600 hover:text-gray-900"
            >
              Sign out
            </button>
          </div>
        </div>
      </header>
      <main className="mx-auto max-w-5xl px-4 py-6">
        <Outlet />
      </main>
    </div>
  );
}

import { render, screen, waitFor, act } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { describe, expect, it, vi } from "vitest";
import { ApplicationsPage } from "./ApplicationsPage";
import * as api from "../api/applications";
import * as cable from "../api/cable";
import type { ApplicationEvent } from "../api/cable";

vi.mock("../api/applications");
vi.mock("../api/cable");

describe("ApplicationsPage realtime", () => {
  it("refetches the list when a realtime event arrives (no reload)", async () => {
    let push: ((event: ApplicationEvent) => void) | null = null;
    vi.mocked(cable.subscribeToApplications).mockImplementation((cb) => {
      push = cb;
      return () => {};
    });
    vi.mocked(api.listApplications).mockResolvedValue({
      data: [],
      meta: { page: 1, per_page: 10, total: 0, total_pages: 0 },
    });

    render(
      <MemoryRouter>
        <ApplicationsPage />
      </MemoryRouter>,
    );

    await waitFor(() => expect(api.listApplications).toHaveBeenCalledTimes(1));

    // Simulate a broadcast (e.g. another user changed a status via the API).
    act(() => {
      push?.({ event: "status_changed", application: { id: "x" } as never });
    });

    await waitFor(() => expect(api.listApplications).toHaveBeenCalledTimes(2));
    expect(await screen.findByText(/no applications/i)).toBeInTheDocument();
  });
});

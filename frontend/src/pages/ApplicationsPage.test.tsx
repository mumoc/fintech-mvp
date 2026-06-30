import { render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { describe, expect, it, vi } from "vitest";
import { ApplicationsPage } from "./ApplicationsPage";
import * as api from "../api/applications";
import type { Application } from "../api/types";

vi.mock("../api/applications");

function sampleApplication(): Application {
  return {
    id: "app-1",
    country: "MX",
    document_type: "CURP",
    amount_requested: "100000.0",
    status: "received",
    risk_score: 31,
    flags: {},
    lock_version: 0,
    requested_at: null,
    created_at: "2026-06-30T00:00:00Z",
    updated_at: "2026-06-30T00:00:00Z",
    bank_record: null,
  };
}

describe("ApplicationsPage", () => {
  it("renders applications fetched from the API", async () => {
    vi.mocked(api.listApplications).mockResolvedValue({
      data: [sampleApplication()],
      meta: { page: 1, per_page: 10, total: 1, total_pages: 1 },
    });

    render(
      <MemoryRouter>
        <ApplicationsPage />
      </MemoryRouter>,
    );

    expect(await screen.findByText("CURP")).toBeInTheDocument();
    expect(screen.getByText("100000.0")).toBeInTheDocument();
    expect(screen.getByText("31")).toBeInTheDocument();
    // status badge in the row (the filter dropdown also contains "received")
    expect(screen.getByRole("link", { name: /view/i })).toHaveAttribute("href", "/applications/app-1");
  });
});

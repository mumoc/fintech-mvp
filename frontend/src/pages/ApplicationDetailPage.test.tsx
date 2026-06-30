import { render, screen } from "@testing-library/react";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { describe, expect, it, vi } from "vitest";
import { ApplicationDetailPage } from "./ApplicationDetailPage";
import * as api from "../api/applications";
import type { Application } from "../api/types";

vi.mock("../api/applications");
vi.mock("../api/cable", () => ({
  subscribeToApplications: () => () => {},
}));

function sampleApplication(): Application {
  return {
    id: "app-1",
    country: "MX",
    document_type: "CURP",
    amount_requested: "100000.0",
    status: "under_review",
    risk_score: 71,
    flags: { requires_review: true, reason: "amount_requested exceeds income ratio" },
    lock_version: 0,
    requested_at: null,
    created_at: "2026-06-30T00:00:00Z",
    updated_at: "2026-06-30T00:00:00Z",
    bank_record: null,
  };
}

describe("ApplicationDetailPage", () => {
  it("renders review flags as readable fields", async () => {
    vi.mocked(api.getApplication).mockResolvedValue(sampleApplication());

    render(
      <MemoryRouter initialEntries={["/applications/app-1"]}>
        <Routes>
          <Route path="/applications/:id" element={<ApplicationDetailPage />} />
        </Routes>
      </MemoryRouter>,
    );

    expect(await screen.findByText("Review flags")).toBeInTheDocument();
    expect(screen.getByText("Requires review")).toBeInTheDocument();
    expect(screen.queryByText(/requires review:/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/reason:/i)).not.toBeInTheDocument();
    expect(screen.getByText("Amount requested exceeds income ratio")).toBeInTheDocument();
  });
});

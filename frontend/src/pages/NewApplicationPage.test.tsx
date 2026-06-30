import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { describe, expect, it, vi } from "vitest";
import { NewApplicationPage } from "./NewApplicationPage";
import * as api from "../api/applications";
import { ApiError } from "../api/client";

vi.mock("../api/applications");

describe("NewApplicationPage", () => {
  it("uses text inputs with decimal keyboards for money fields", async () => {
    vi.mocked(api.listCountries).mockResolvedValue({
      data: [{ code: "MX", document_type: "CURP" }],
    });

    render(
      <MemoryRouter>
        <NewApplicationPage />
      </MemoryRouter>,
    );

    expect(await screen.findByLabelText(/amount requested/i)).toHaveAttribute("type", "text");
    expect(screen.getByLabelText(/amount requested/i)).toHaveAttribute("inputmode", "decimal");
    expect(screen.getByLabelText(/amount requested/i)).toHaveAttribute("autocomplete", "off");
    expect(screen.getByLabelText(/monthly income/i)).toHaveAttribute("type", "text");
    expect(screen.getByLabelText(/monthly income/i)).toHaveAttribute("inputmode", "decimal");
    expect(screen.getByLabelText(/monthly income/i)).toHaveAttribute("autocomplete", "off");
  });

  it("surfaces the 422 validation message on an invalid document", async () => {
    vi.mocked(api.listCountries).mockResolvedValue({
      data: [{ code: "MX", document_type: "CURP" }],
    });
    vi.mocked(api.createApplication).mockRejectedValue(
      new ApiError(422, "invalid_document", ["document_number must be a valid CURP"]),
    );

    render(
      <MemoryRouter>
        <NewApplicationPage />
      </MemoryRouter>,
    );

    await userEvent.type(screen.getByLabelText(/document number/i), "NOT-A-CURP");
    await userEvent.click(screen.getByRole("button", { name: /create application/i }));

    expect(await screen.findByText(/must be a valid CURP/i)).toBeInTheDocument();
    expect(screen.getByRole("alert")).toHaveTextContent(/invalid document/i);
  });
});

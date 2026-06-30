require "rails_helper"

RSpec.describe Countries::Catalog do
  it "lists supported countries with their document type" do
    expect(described_class.all).to include("code" => "MX", "document_type" => "CURP")
  end

  it "serves the catalog from cache within the TTL (built once)" do
    expect(described_class).to receive(:build).once.and_call_original

    described_class.all
    described_class.all
  end
end

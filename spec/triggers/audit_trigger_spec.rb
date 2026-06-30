require "rails_helper"

RSpec.describe "audit trigger", type: :model do
  it "writes one audit_log row with the old/new diff on update" do
    application = create(:credit_application, status: "received")

    expect { application.update!(status: "approved") }
      .to change {
        AuditLog.where(table_name: "credit_applications", record_id: application.id, action: "UPDATE").count
      }.by(1)

    log = AuditLog.where(record_id: application.id, action: "UPDATE").last
    expect(log.old_data["status"]).to eq("received")
    expect(log.new_data["status"]).to eq("approved")
  end

  it "records an INSERT row when an application is created" do
    application = create(:credit_application)

    expect(AuditLog.where(record_id: application.id, action: "INSERT").count).to eq(1)
  end

  it "stores ciphertext, never plaintext PII" do
    application = create(:credit_application, full_name: "Top Secret Person")
    application.update!(status: "approved")

    log = AuditLog.where(record_id: application.id, action: "UPDATE").last
    expect(log.new_data["full_name"]).to be_present
    expect(log.new_data["full_name"]).not_to include("Top Secret Person")
  end
end

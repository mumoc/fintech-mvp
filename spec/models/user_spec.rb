require "rails_helper"

RSpec.describe User, type: :model do
  it "has a valid factory" do
    expect(build(:user)).to be_valid
  end

  it { is_expected.to validate_presence_of(:email) }
  it { is_expected.to define_enum_for(:role).with_values(operator: 0, analyst: 1, admin: 2) }

  it "requires a unique email (case-insensitive)" do
    create(:user, email: "Dup@Example.com")
    duplicate = build(:user, email: "dup@example.com")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:email]).to be_present
  end

  it "authenticates with the correct password via has_secure_password" do
    user = create(:user, password: "s3cret-pass")

    expect(user.authenticate("s3cret-pass")).to eq(user)
    expect(user.authenticate("wrong")).to be(false)
  end
end

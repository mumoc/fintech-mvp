require "rails_helper"

RSpec.describe StateTransition, type: :model do
  it "has a valid factory" do
    expect(build(:state_transition)).to be_valid
  end

  it { is_expected.to belong_to(:credit_application) }
  it { is_expected.to belong_to(:actor).class_name("User").optional }
  it { is_expected.to validate_presence_of(:to_state) }
end

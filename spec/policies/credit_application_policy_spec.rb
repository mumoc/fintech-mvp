require "rails_helper"

RSpec.describe CreditApplicationPolicy do
  subject(:policy) { described_class.new(user, CreditApplication.new) }

  describe "operator" do
    let(:user) { build(:user, role: :operator) }

    it { expect(policy.index?).to be(true) }
    it { expect(policy.show?).to be(true) }
    it { expect(policy.create?).to be(true) }
    it { expect(policy.update_status?).to be(false) }
    it { expect(policy.view_pii?).to be(false) }
  end

  describe "analyst" do
    let(:user) { build(:user, role: :analyst) }

    it { expect(policy.index?).to be(true) }
    it { expect(policy.show?).to be(true) }
    it { expect(policy.create?).to be(true) }
    it { expect(policy.update_status?).to be(true) }
    it { expect(policy.view_pii?).to be(true) }
  end

  describe "admin" do
    let(:user) { build(:user, role: :admin) }

    it { expect(policy.index?).to be(true) }
    it { expect(policy.show?).to be(true) }
    it { expect(policy.create?).to be(true) }
    it { expect(policy.update_status?).to be(true) }
    it { expect(policy.view_pii?).to be(true) }
  end

  describe "Scope" do
    it "returns all records" do
      operator = build(:user, role: :operator)
      scope = described_class::Scope.new(operator, CreditApplication.all).resolve

      expect(scope).to eq(CreditApplication.all)
    end
  end
end

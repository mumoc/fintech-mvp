require "rails_helper"

RSpec.describe ApplicationsChannel, type: :channel do
  it "subscribes and streams from the shared applications stream" do
    stub_connection(current_user: build(:user))

    subscribe

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from(ApplicationsChannel::STREAM)
  end
end

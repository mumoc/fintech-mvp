require "sidekiq/testing"

# Jobs are queued (not run) by default; specs assert on the queue or drain it
# explicitly with Sidekiq::Testing.inline!.
Sidekiq::Testing.fake!

RSpec.configure do |config|
  config.before do
    Sidekiq::Job.clear_all
  end
end

namespace :outbox do
  desc "Continuously drain the transactional outbox (dedicated dispatcher process)"
  task dispatch: :environment do
    interval = Float(ENV.fetch("OUTBOX_DISPATCH_INTERVAL", "1"))
    $stdout.sync = true
    puts({ event: "outbox.dispatcher.started", interval: interval }.to_json)

    loop do
      processed = Outbox::Dispatcher.new.drain
      # Only sleep when idle, so a backlog drains at full speed. Multiple
      # replicas are safe (FOR UPDATE SKIP LOCKED).
      sleep(interval) if processed.zero?
    end
  end
end

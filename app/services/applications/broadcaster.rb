module Applications
  # Pushes realtime application updates over ActionCable. The payload is the
  # NON-PII (redacted) view, since one shared stream serves every role.
  class Broadcaster
    def self.application_changed(application, event:)
      ActionCable.server.broadcast(
        ApplicationsChannel::STREAM,
        { event: event, application: CreditApplicationSerializer.redacted(application) },
      )
    end
  end
end

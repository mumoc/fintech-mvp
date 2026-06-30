# Realtime application updates. All authenticated users subscribe to one shared
# stream; broadcasts carry only non-PII fields (see Applications::Broadcaster).
class ApplicationsChannel < ApplicationCable::Channel
  STREAM = "applications".freeze

  def subscribed
    stream_from STREAM
  end
end

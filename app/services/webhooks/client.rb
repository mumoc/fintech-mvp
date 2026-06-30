require "net/http"
require "uri"

module Webhooks
  # Thin HTTP POST wrapper (stdlib Net::HTTP). Isolated so it is trivial to stub
  # in tests and swap for a more featureful client later.
  class Client
    Response = Data.define(:code, :body) do
      def success? = (200..299).cover?(code)
    end

    def self.post(url, body, headers = {})
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 5
      http.read_timeout = 5

      request = Net::HTTP::Post.new(uri.request_uri, headers)
      request.body = body
      response = http.request(request)

      Response.new(code: response.code.to_i, body: response.body)
    end
  end
end

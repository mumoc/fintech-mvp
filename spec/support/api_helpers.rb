module ApiHelpers
  # Authorization header carrying a valid JWT for the given user.
  def auth_headers(user)
    token = JsonWebToken.encode({ sub: user.id, role: user.role })
    { "Authorization" => "Bearer #{token}" }
  end
end

RSpec.configure do |config|
  config.include ApiHelpers, type: :request
end

# Guards API controllers with JWT bearer-token authentication. Included in
# ApplicationController so every endpoint is protected by default; controllers
# that must be public (e.g. login) opt out with `skip_before_action`.
module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_request!
    attr_reader :current_user
  end

  private

  def authenticate_request!
    payload = JsonWebToken.decode(bearer_token)
    @current_user = User.find_by(id: payload[:sub]) if payload
    render_unauthorized unless @current_user
  end

  def bearer_token
    request.headers["Authorization"].to_s.split.last
  end

  def render_unauthorized
    render json: { error: "Unauthorized" }, status: :unauthorized
  end
end

class ApplicationController < ActionController::API
  include Authenticatable
  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError, with: :render_forbidden

  # Pundit authorizes against the JWT-authenticated user.
  def pundit_user
    current_user
  end

  private

  def render_forbidden
    render json: { error: "Forbidden" }, status: :forbidden
  end
end

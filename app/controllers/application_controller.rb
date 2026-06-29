class ApplicationController < ActionController::API
  include Authenticatable
  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError, with: :render_forbidden
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  # Pundit authorizes against the JWT-authenticated user.
  def pundit_user
    current_user
  end

  private

  def render_forbidden
    render json: { error: "Forbidden" }, status: :forbidden
  end

  def render_not_found
    render json: { error: "Not Found" }, status: :not_found
  end
end

module Api
  module V1
    # Returns the authenticated user — a minimal protected endpoint used to
    # confirm a token is valid.
    class ProfilesController < ApplicationController
      # GET /api/v1/me
      def show
        render json: { id: current_user.id, email: current_user.email, role: current_user.role }, status: :ok
      end
    end
  end
end

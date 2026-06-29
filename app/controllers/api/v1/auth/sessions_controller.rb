module Api
  module V1
    module Auth
      class SessionsController < ApplicationController
        skip_before_action :authenticate_request!, only: :create

        # POST /api/v1/login
        def create
          user = User.find_by(email: params[:email])

          if user&.authenticate(params[:password])
            token = JsonWebToken.encode({ sub: user.id, role: user.role })
            render json: { token: token, role: user.role }, status: :ok
          else
            render json: { error: "Invalid email or password" }, status: :unauthorized
          end
        end
      end
    end
  end
end

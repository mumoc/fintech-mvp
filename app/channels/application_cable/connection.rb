module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    # Browsers can't set Authorization headers on a WebSocket, so the JWT is
    # passed as a query param (?token=…).
    def find_verified_user
      payload = JsonWebToken.decode(request.params[:token])
      user = User.find_by(id: payload[:sub]) if payload
      user || reject_unauthorized_connection
    end
  end
end

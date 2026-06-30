module Api
  module V1
    # Inbound webhooks authenticate via HMAC signature (not JWT).
    class WebhooksController < ApplicationController
      skip_before_action :authenticate_request!, only: :bank

      # POST /api/v1/webhooks/bank
      def bank
        unless WebhookSignature.valid?(request.raw_post, request.headers["X-Webhook-Signature"])
          return render json: { error: "invalid_signature" }, status: :unauthorized
        end

        result = Webhooks::ProcessBankConfirmation.call!(
          idempotency_key: bank_params[:idempotency_key],
          source: "bank",
          payload: bank_params.to_h
        )

        if result.success?
          render json: { status: "ok" }, status: :ok
        else
          render json: { error: result.error.code, messages: result.error.messages },
                 status: :unprocessable_content
        end
      end

      private

      def bank_params
        params.permit(:idempotency_key, :application_id, :event)
      end
    end
  end
end

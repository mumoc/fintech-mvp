module Api
  module V1
    class CreditApplicationsController < ApplicationController
      # POST /api/v1/credit_applications
      def create
        authorize CreditApplication

        result = Applications::CreateApplication.call!(params: create_params, actor: current_user)

        if result.success?
          render json: serialize(result.value), status: :created
        else
          render json: { error: result.error.code, messages: result.error.messages },
                 status: :unprocessable_content
        end
      end

      private

      def create_params
        params.require(:credit_application).permit(
          :country, :full_name, :document_number, :amount_requested, :monthly_income
        )
      end

      def serialize(application)
        CreditApplicationSerializer.new(application, user: current_user).as_json
      end
    end
  end
end

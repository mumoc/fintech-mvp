module Api
  module V1
    class CreditApplicationsController < ApplicationController
      # GET /api/v1/credit_applications
      def index
        authorize CreditApplication

        page = Applications::Search.call(
          scope: policy_scope(CreditApplication),
          filters: params.permit(:country, :status, :from, :to).to_h.symbolize_keys,
          page: params[:page],
          per_page: params[:per_page]
        )

        render json: {
          data: page.records.map { |application| serialize(application) },
          meta: {
            page: page.page,
            per_page: page.per_page,
            total: page.total,
            total_pages: page.total_pages
          }
        }, status: :ok
      end

      # GET /api/v1/credit_applications/:id
      def show
        application = policy_scope(CreditApplication).includes(:bank_record).find(params[:id])
        authorize application

        render json: Applications::CachedView.fetch(application, user: current_user), status: :ok
      end

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

      # PATCH /api/v1/credit_applications/:id/status
      def update_status
        application = policy_scope(CreditApplication).find(params[:id])
        authorize application, :update_status?

        result = Applications::UpdateStatus.call!(
          application: application,
          event: status_params[:event],
          actor: current_user,
          reason: status_params[:reason],
          expected_lock_version: status_params[:lock_version]
        )

        if result.success?
          render json: serialize(result.value), status: :ok
        else
          render json: { error: result.error.code, messages: result.error.messages },
                 status: status_for(result.error.code)
        end
      end

      private

      def status_params
        params.require(:credit_application).permit(:event, :reason, :lock_version)
      end

      def status_for(code)
        code == :conflict ? :conflict : :unprocessable_content
      end

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

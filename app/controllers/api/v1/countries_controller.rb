module Api
  module V1
    # Supported countries + their document types (served from the cached catalog).
    class CountriesController < ApplicationController
      # GET /api/v1/countries
      def index
        render json: { data: Countries::Catalog.all }, status: :ok
      end
    end
  end
end

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      post "login", to: "auth/sessions#create"
      get "me", to: "profiles#show"

      resources :credit_applications, only: [ :index, :show, :create ] do
        member do
          patch :status, action: :update_status
        end
      end

      post "webhooks/bank", to: "webhooks#bank"

      resources :countries, only: [ :index ]
    end
  end
end

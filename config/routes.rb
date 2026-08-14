Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  devise_for :users
  root "home#index"
  resources :groups, only: %i[index create update]
  get "groups/:id", to: "groups#show", constraints: CanonicalUuidV7RouteConstraint.new

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
end

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  devise_for :users
  root "home#index"
  resources :invitations, only: :index
  post "invitations/:id/accept", to: "invitations#accept", constraints: CanonicalUuidV7RouteConstraint.new
  post "invitations/:id/decline", to: "invitations#decline", constraints: CanonicalUuidV7RouteConstraint.new
  resources :groups, only: %i[index create update] do
    post :archive
    post :restore
    post "memberships/:id/deactivate", to: "memberships#deactivate"
    post "memberships/:id/reactivate", to: "memberships#reactivate"
    post "memberships/:id/transfer_ownership", to: "memberships#transfer_ownership"
    patch "memberships/order", to: "memberships#order"
    resources :expenses, only: %i[create show]
    patch "expenses/:id/description", to: "expenses#update_description"
    post "expenses/:id/correct", to: "expenses#correct"
    resources :payments, only: %i[create show]
    post "payments/:id/confirm", to: "payments#confirm"
    post "payments/:id/cancel", to: "payments#cancel"
    resources :invitations, only: :create, controller: "group_invitations"
    post "invitations/:id/revoke", to: "group_invitations#revoke", constraints: CanonicalUuidV7RouteConstraint.new
  end
  get "groups/:id", to: "groups#show", constraints: CanonicalUuidV7RouteConstraint.new

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
end

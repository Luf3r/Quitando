Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  devise_for :users
  root "home#index"
  uuid_v7 = ->(*parameter_names) { CanonicalUuidV7RouteConstraint.new(*parameter_names) }

  resources :invitations, only: :index
  post "invitations/:id/accept", to: "invitations#accept", constraints: CanonicalUuidV7RouteConstraint.new
  post "invitations/:id/decline", to: "invitations#decline", constraints: CanonicalUuidV7RouteConstraint.new
  resources :groups, only: %i[index create]
  resources :groups, only: :update, constraints: uuid_v7.call(:id)

  scope "groups/:group_id", as: "group", constraints: { group_id: CanonicalUuidV7RouteConstraint::ROUTE_PATTERN } do
    post :archive, to: "groups#archive", as: :archive
    post :restore, to: "groups#restore", as: :restore

    post "memberships/:id/deactivate", to: "memberships#deactivate", constraints: uuid_v7.call(:id)
    post "memberships/:id/reactivate", to: "memberships#reactivate", constraints: uuid_v7.call(:id)
    post "memberships/:id/transfer_ownership", to: "memberships#transfer_ownership", constraints: uuid_v7.call(:id)
    patch "memberships/order", to: "memberships#order", as: :memberships_order

    resources :expenses, only: :create
    resources :expenses, only: :show, constraints: uuid_v7.call(:id)
    patch "expenses/:id/description", to: "expenses#update_description", constraints: uuid_v7.call(:id)
    post "expenses/:id/correct", to: "expenses#correct", constraints: uuid_v7.call(:id)

    resources :payments, only: :create
    resources :payments, only: :show, constraints: uuid_v7.call(:id)
    post "payments/:id/confirm", to: "payments#confirm", constraints: uuid_v7.call(:id)
    post "payments/:id/cancel", to: "payments#cancel", constraints: uuid_v7.call(:id)

    resources :invitations, only: :create, controller: "group_invitations"
    post "invitations/:id/revoke", to: "group_invitations#revoke", constraints: uuid_v7.call(:id)
  end
  get "groups/:id", to: "groups#show", constraints: CanonicalUuidV7RouteConstraint.new

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
end

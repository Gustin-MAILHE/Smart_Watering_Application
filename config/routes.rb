Rails.application.routes.draw do
  devise_for :users
  get "up" => "rails/health#show", as: :rails_health_check
  root "home#index"

  resources :accounts, only: [ :index, :update, :destroy ]
  resources :stats, only: [ :index, :show ]
  resources :zones, only: [ :index ]
  resources :settings, only: [ :index ]
  post "set_language", to: "settings#set_language"
  post "update_preferences", to: "settings#update_preferences"

  resources :themes, only: [ :index ]
  resources :abouts, only: [ :index ]

  resources :gardens, only: [ :index ]
  resources :garden_zones, only: [ :index, :create, :update, :destroy ]
end

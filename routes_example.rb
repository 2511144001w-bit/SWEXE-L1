Rails.application.routes.draw do
  resources :media_items
  root "media_items#index"
end

# frozen_string_literal: true

Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :clinical_tests, only: :show do
        member do
          patch :transition_workflow
          patch :transition_result
          post :review
        end
      end
    end
  end
end

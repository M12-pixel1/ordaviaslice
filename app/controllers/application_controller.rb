# frozen_string_literal: true

class ApplicationController < ActionController::Base
  protect_from_forgery with: :null_session

  private

  # Host-app placeholder. Replace with real auth plumbing.
  def current_user
    nil
  end
end

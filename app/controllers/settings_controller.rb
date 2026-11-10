# frozen_string_literal: true

class SettingsController < ApplicationController
  def index
  end

  def set_language
    session[:locale] = params[:locale]
    redirect_back fallback_location: root_path
  end
end

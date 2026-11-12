# frozen_string_literal: true

class SettingsController < ApplicationController
  before_action :authenticate_user!, only: [:update_preferences]
  def index
  end

  def set_language
    session[:locale] = params[:locale]
    redirect_back fallback_location: root_path
  end

  def update_preferences
    if current_user.update(preference_params)
      redirect_back fallback_location: root_path, notice: "Préférence mise à jour."
    else
      redirect_back fallback_location: root_path, alert: "Erreur lors de la mise à jour."
    end
  end

  def preference_params
    params.permit(:temperature_unit, :brightness_unit, :humidity_unit) # allow changes only to these three parameters
  end
end

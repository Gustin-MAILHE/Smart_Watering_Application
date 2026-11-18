class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  around_action :switch_locale
  before_action :configure_permitted_parameters, if: :devise_controller?

  stale_when_importmap_changes

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :username ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :username ])
  end

  private

  def switch_locale(&action)
    available_locales = I18n.available_locales.map(&:to_s)
    locale = [ params[:locale], session[:locale] ].find { |value| available_locales.include?(value) }
    locale ||= I18n.default_locale

    session[:locale] = locale.to_s
    I18n.with_locale(locale, &action)
  end
end

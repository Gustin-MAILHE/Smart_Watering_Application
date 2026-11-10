class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :set_locale # set_locale for all the pages
  before_action :configure_permitted_parameters, if: :devise_controller? # configure_permitted_parameters only for Devise

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # allow username field
  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:username]) # allow username when sign up account
    devise_parameter_sanitizer.permit(:account_update, keys: [:username]) # allow username when edit account
  end

  private
  def set_locale
    I18n.locale = params[:locale] || session[:locale] || I18n.default_locale # Sets the app's active locale from URL params, current session, or system default.
    session[:locale] = I18n.locale # Persists the selected locale in the session so it remains active across pages.
  end
end

class GardensController < ApplicationController
  def index
    @zones = user_signed_in? ? current_user.zones.order(:id) : []
    response.headers["Cache-Control"] = "no-store"
  end
end

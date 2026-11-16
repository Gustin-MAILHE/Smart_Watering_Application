class GardenZonesController < ApplicationController
  before_action :authenticate_user!

  rescue_from ActiveRecord::RecordNotFound do
    render json: { errors: [ "Zone introuvable." ] }, status: :not_found
  end

  rescue_from ActiveRecord::RecordNotUnique do
    render json: { errors: [ "Une autre zone utilise déjà ce nom." ] }, status: :unprocessable_entity
  end

  def index
    response.headers["Cache-Control"] = "no-store"
    render json: current_user.zones.order(:id).map(&:garden_data)
  end

  def create
    zone = current_user.zones.build(zone_params)
    save_zone(zone, :created)
  end

  def update
    zone = current_user.zones.find(params[:id])
    zone.assign_attributes(zone_params)
    save_zone(zone, :ok)
  end

  def destroy
    current_user.zones.find(params[:id]).destroy!
    head :no_content
  end

  private

  def zone_params
    params.require(:zone).permit(:name, :crop, :schedule, :watering_time_slots, :watering_starts_on, :watering_ends_on,
      watering_time_slots: [ :start, :end ], thresholds: [ :humidity, :temperature, :brightness ])
  end

  def save_zone(zone, status)
    if zone.save
      render json: zone.garden_data, status: status
    else
      render json: { errors: zone.errors.full_messages }, status: :unprocessable_entity
    end
  end
end

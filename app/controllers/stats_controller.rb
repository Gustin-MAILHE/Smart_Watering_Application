# frozen_string_literal: true

class StatsController < ApplicationController
  def index
    @days = DemoStatistics::DAYS
  end

  def show
    date = params[:id].tr("-", "/")
    @day = DemoStatistics::DAYS.find { |day| day[:date] == date }
    return redirect_to stats_path unless @day

    @averages = DemoStatistics::AVERAGES
    @readings = DemoStatistics::READINGS
    @zones = DemoStatistics::ZONES
    @waterings = DemoStatistics::WATERINGS
  end
end

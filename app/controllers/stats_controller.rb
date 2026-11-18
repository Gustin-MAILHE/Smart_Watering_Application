# frozen_string_literal: true

class StatsController < ApplicationController
  # Front-end only: these simulated days will come from the back end once the sensor history is stored.
  DAYS = [
    { date: "01/01/2026", humidity: 70, brightness: 50, temperature: 25 },
    { date: "02/01/2026", humidity: 64, brightness: 72, temperature: 27 },
    { date: "03/01/2026", humidity: 81, brightness: 35, temperature: 21 },
    { date: "04/01/2026", humidity: 75, brightness: 48, temperature: 23 },
    { date: "05/01/2026", humidity: 68, brightness: 60, temperature: 26 }
  ].freeze # One summary per recorded day

  # List of the recorded days.
  def index
    @days = DAYS
  end

  # Details of one day, e.g. /stats/01-01-2026.
  def show
    date = params[:id].tr("-", "/") # "01-01-2026" -> "01/01/2026"
    @day = DAYS.find { |day| day[:date] == date } # Same figures as the list
    redirect_to stats_path unless @day # Unknown day: back to the list
  end
end

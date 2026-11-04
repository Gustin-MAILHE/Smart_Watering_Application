class HomeController < ApplicationController
  def index
    @average = { humidity: 70, brightness: 50, temperature: 25, status: "Bon" }

    @crops = [
      { name: "Tomates",    humidity: 70, brightness: 50, temperature: 25, watering: :info, health: :ok },
      { name: "Salades",    humidity: 40, brightness: 40, temperature: 15, watering: :off,  health: :warning },
      { name: "Oignons",    humidity: 0,  brightness: 0,  temperature: 0,  watering: :off,  health: :alert },
      { name: "Concombres", humidity: 70, brightness: 50, temperature: 25, watering: :info, health: :ok },
      { name: "Carottes",   humidity: 70, brightness: 50, temperature: 25, watering: :info, health: :ok }
    ]
  end
end
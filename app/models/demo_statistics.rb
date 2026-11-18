# Données provisoires, en attendant l’historique des capteurs.
class DemoStatistics
  DAYS = [
    { date: "01/01/2026", humidity: 70, brightness: 50, temperature: 25 },
    { date: "02/01/2026", humidity: 64, brightness: 72, temperature: 27 },
    { date: "03/01/2026", humidity: 81, brightness: 35, temperature: 21 },
    { date: "04/01/2026", humidity: 75, brightness: 48, temperature: 23 },
    { date: "05/01/2026", humidity: 68, brightness: 60, temperature: 26 }
  ].freeze

  AVERAGES = { temperature_min: 17, temperature_max: 31, water: "33,5" }.freeze
  READINGS = [
    { hour: "00:00", temperature: 18, humidity: 82, brightness: 0 },
    { hour: "03:00", temperature: 17, humidity: 85, brightness: 0 },
    { hour: "06:00", temperature: 19, humidity: 80, brightness: 15 },
    { hour: "09:00", temperature: 24, humidity: 71, brightness: 55 },
    { hour: "12:00", temperature: 30, humidity: 58, brightness: 95 },
    { hour: "15:00", temperature: 31, humidity: 55, brightness: 85 },
    { hour: "18:00", temperature: 27, humidity: 63, brightness: 45 },
    { hour: "21:00", temperature: 22, humidity: 74, brightness: 5 }
  ].freeze
  ZONES = [
    { name: "Zone 1", crop: "Tomates", water: "15,5", waterings: 2 },
    { name: "Zone 2", crop: "Laitues", water: "5,5", waterings: 1 },
    { name: "Zone 3", crop: "Carottes", water: "12,5", waterings: 2 }
  ].freeze
  WATERINGS = [
    { time: "08:30 – 08:45", zone: "Zone 1", liters: "9,5" },
    { time: "09:00 – 09:10", zone: "Zone 2", liters: "5,5" },
    { time: "10:15 – 10:30", zone: "Zone 3", liters: "8,0" },
    { time: "15:45 – 15:55", zone: "Zone 3", liters: "4,5" },
    { time: "16:30 – 16:40", zone: "Zone 1", liters: "6,0" }
  ].freeze
end

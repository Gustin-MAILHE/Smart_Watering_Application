export const DEFAULT_WATERING_SLOTS = {
  "Every 2 days - 6:00 AM": [{ start: "06:00", end: "06:30" }],
  "Every day - 7:00 AM": [{ start: "07:00", end: "07:30" }],
  "Every 3 days - 8:00 PM": [{ start: "20:00", end: "20:30" }]
}
export const DEMO_SENSORS = [
  { id: "temperature-1", type: "temp", name: "Température · T-01", health: "healthy", reading: "28°C", initialZoneId: 1 },
  { id: "humidity-1", type: "humidity", name: "Humidité · H-01", health: "low-battery", reading: "42%", initialZoneId: 1 },
  { id: "brightness-1", type: "brightness", name: "Luminosité · B-01", health: "offline", reading: null, initialZoneId: 1 },
  { id: "temperature-2", type: "temp", name: "Température · T-02", health: "healthy", reading: "19°C", initialZoneId: 2 },
  { id: "humidity-2", type: "humidity", name: "Humidité · H-02", health: "healthy", reading: "80%", initialZoneId: 2 },
  { id: "brightness-2", type: "brightness", name: "Luminosité · B-02", health: "healthy", reading: "620 lx", initialZoneId: 2 },
  { id: "temperature-3", type: "temp", name: "Température · T-03", health: "healthy", reading: "22°C" },
  { id: "humidity-3", type: "humidity", name: "Humidité · H-03", health: "low-battery", reading: "58%", initialZoneId: null },
  { id: "brightness-3", type: "brightness", name: "Luminosité · B-03", health: "offline", reading: null }
]
export const SENSOR_HEALTH = {
  healthy: "En bon état", "low-battery": "Batterie faible", offline: "Hors ligne"
}

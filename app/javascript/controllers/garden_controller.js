import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "smartWatering.garden.v1"
const DEMO_SENSORS = [
  { id: "temperature-1", type: "temp", name: "Température · T-01", health: "healthy", reading: "24°C", initialZoneId: 1 },
  { id: "humidity-1", type: "humidity", name: "Humidité · H-01", health: "healthy", reading: "65%", initialZoneId: 1 },
  { id: "brightness-1", type: "brightness", name: "Luminosité · B-01", health: "healthy", reading: "850 lx", initialZoneId: 1 },
  { id: "temperature-2", type: "temp", name: "Température · T-02", health: "healthy", reading: "19°C", initialZoneId: 2 },
  { id: "humidity-2", type: "humidity", name: "Humidité · H-02", health: "healthy", reading: "80%", initialZoneId: 2 },
  { id: "brightness-2", type: "brightness", name: "Luminosité · B-02", health: "healthy", reading: "620 lx", initialZoneId: 2 },
  { id: "temperature-3", type: "temp", name: "Température · T-03", health: "healthy", reading: "22°C" },
  { id: "humidity-3", type: "humidity", name: "Humidité · H-03", health: "low-battery", reading: "58%" },
  { id: "brightness-3", type: "brightness", name: "Luminosité · B-03", health: "offline", reading: null }
]
const SENSOR_HEALTH = {
  healthy: "En bon état", "low-battery": "Batterie faible", offline: "Hors ligne"
}

/** Persists account zones in Rails and keeps demo configuration in browser storage. */
export default class extends Controller {
  static values = { accountId: Number, zones: Array, zonesUrl: String }

  static targets = [
    "title", "zoneList", "zoneBtn", "zoneAdd", "crop", "schedule",
    "temp", "humidity", "brightness", "sensorTags", "emptySensors",
    "readingsNote", "storageNotice", "zoneName", "nameError", "zoneContent", "emptyGarden",
    "sensorSelect", "sensorAssign", "presetSelect", "presetName", "presetError",
    "presetApply", "presetUpdate", "presetDelete", "humidityThreshold", "temperatureThreshold", "brightnessThreshold",
    "localConfiguration"
  ]

  /** Restores state and rebuilds buttons after initial loading or a Turbo visit. */
  connect() {
    this.zoneRequestPending = false
    this.requestController = new AbortController()
    this.state = this.loadState()
    if (this.accountIdValue) this.restoreAccountZones()
    this.initializePresets()
    this.renderZoneButtons()
    this.renderSelectedZone()
    console.log("SUCCESS: Garden controller connected.")
  }

  disconnect() {
    this.requestController.abort()
  }

  get storageKey() {
    return this.accountIdValue ? `${STORAGE_KEY}.account.${this.accountIdValue}` : STORAGE_KEY
  }

  /** Server settings take precedence; legacy account settings remain available for explicit transfer. */
  restoreAccountZones() {
    const cached = new Map(this.state.zones.map((zone) => [zone.id, zone]))
    this.state.zones = this.zonesValue.map((zone) => {
      const local = cached.get(zone.id)
      const restored = { sensorIds: [], ...local, ...zone, localConfiguration: false }
      if (!zone.configurationSaved && local) {
        Object.assign(restored, {
          crop: local.crop, schedule: local.schedule, thresholds: local.thresholds ?? this.emptyThresholds(),
          localConfiguration: true
        })
      }
      return restored
    })
    if (!this.state.zones.some((zone) => zone.id === this.state.selectedZoneId)) {
      this.state.selectedZoneId = this.state.zones[0]?.id ?? null
    }
  }

  /** Mutations keep the displayed list unchanged until Rails confirms the save. */
  async requestZone(method, id = null, attributes = null) {
    this.zoneRequestPending = true
    this.zoneListTarget.inert = true
    this.zoneContentTargets.forEach((content) => { content.inert = true })
    this.element.setAttribute("aria-busy", "true")
    try {
      const url = id === null ? this.zonesUrlValue : `${this.zonesUrlValue}/${id}`
      const response = await fetch(url, {
        method,
        credentials: "same-origin",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content ?? ""
        },
        body: attributes === null ? undefined : JSON.stringify({ zone: attributes }),
        signal: this.requestController.signal
      })
      if (response.status === 401) throw new Error("Votre session a expiré. Reconnectez-vous pour modifier vos zones.")
      if (!response.ok) {
        const data = await response.json().catch(() => ({}))
        throw new Error(data.errors?.join(" ") || "Impossible d’enregistrer la modification. Rechargez la page et réessayez.")
      }
      return response.status === 204 ? null : await response.json()
    } finally {
      this.zoneRequestPending = false
      this.zoneListTarget.inert = false
      this.zoneContentTargets.forEach((content) => { content.inert = false })
      this.element.removeAttribute("aria-busy")
    }
  }

  showRequestError(error) {
    if (error.name === "AbortError") return
    this.showStorageNotice(error.name === "TypeError"
      ? "Impossible de joindre le serveur. La modification n’a pas été confirmée ; rechargez la page avant de réessayer."
      : error.message)
  }

  /** Saves all zone settings together; a failed request restores confirmed field values. */
  async saveConfiguration(zone, changes) {
    if (this.zoneRequestPending) return false
    if (this.accountIdValue) {
      try {
        const settings = { crop: zone.crop, schedule: zone.schedule, thresholds: zone.thresholds, ...changes }
        const saved = await this.requestZone("PATCH", zone.id, {
          crop: settings.crop, schedule: settings.schedule, thresholds: settings.thresholds
        })
        Object.assign(zone, changes, saved, { localConfiguration: false })
        this.localConfigurationTarget.hidden = true
      } catch (error) {
        this.renderConfigurationFields(zone)
        this.showRequestError(error)
        return false
      }
    } else Object.assign(zone, changes)
    return true
  }

  async importConfiguration() {
    const zone = this.state.zones.find((zone) => zone.id === this.state.selectedZoneId)
    if (!zone?.localConfiguration || !await this.saveConfiguration(zone, {})) return
    this.saveState()
  }

  renderConfigurationFields(zone) {
    this.cropTarget.value = zone.crop
    this.scheduleTarget.value = zone.schedule
    for (const key of ["humidity", "temperature", "brightness"]) {
      this[`${key}ThresholdTarget`].value = zone.thresholds[key] ?? ""
    }
  }

  /** @returns {object} A fresh demo state when no saved zones are available. */
  defaultState() {
    if (this.accountIdValue) {
      return { version: 1, numberingVersion: 1, selectedZoneId: null, nextZoneId: 1, zones: [] }
    }
    return {
      version: 1,
      numberingVersion: 1,
      selectedZoneId: 1,
      nextZoneId: 3,
      zones: [
        { id: 1, name: "Zone 1", crop: "Tomatoes", schedule: "Every 2 days - 6:00 AM", sensorIds: ["temperature-1", "humidity-1", "brightness-1"] },
        { id: 2, name: "Zone 2", crop: "Lettuce", schedule: "Every day - 7:00 AM", sensorIds: ["temperature-2", "humidity-2", "brightness-2"] }
      ]
    }
  }

  /** @returns {object} Valid saved state, or usable defaults if storage fails. */
  loadState() {
    this.showStorageNotice("")
    try {
      const savedText = window.localStorage.getItem(this.storageKey)
      if (savedText === null) return this.state || this.defaultState()

      const savedState = JSON.parse(savedText)
      if (!this.isValidState(savedState)) throw new Error("Invalid saved garden data")

      savedState.zones.forEach((zone) => {
        zone.name = (zone.name ?? `Zone ${zone.id}`).trim()
        zone.sensorIds = this.sensorIdsForZone(zone)
      })
      const highestId = savedState.zones.reduce((highest, zone) => Math.max(highest, zone.id), 2)
      savedState.nextZoneId = Math.max(highestId + 1, Number.isSafeInteger(savedState.nextZoneId) ? savedState.nextZoneId : 0)
      this.restoreZoneNumbering(savedState)
      if (!savedState.zones.some((zone) => zone.id === savedState.selectedZoneId)) {
        savedState.selectedZoneId = savedState.zones[0]?.id ?? null
      }
      return savedState
    } catch (error) {
      this.showStorageNotice(
        "Impossible de charger les zones enregistrées. Vous pouvez continuer, mais vos modifications risquent d’être perdues en quittant ou en rechargeant la page."
      )
      console.warn("Garden storage could not be loaded:", error)
      return this.state || this.defaultState()
    }
  }

  /** @param {object} state Repairs old generated names once, retaining custom names and device identities. */
  restoreZoneNumbering(state) {
    if (state.numberingVersion === 1) return
    const automaticZones = state.zones.filter((zone) => zone.name === `Zone ${zone.id}`)
    const reservedNames = new Set(state.zones.filter((zone) => !automaticZones.includes(zone)).map((zone) => zone.name.toLowerCase()))
    automaticZones.forEach((zone) => {
      zone.name = this.nextZoneName(reservedNames, state.zones.length)
      reservedNames.add(zone.name.toLowerCase())
    })
    state.numberingVersion = 1
  }

  /** @param {Set<string>} usedNames @param {number} zoneCount Finds the first free display number. @returns {string} */
  nextZoneName(usedNames, zoneCount) {
    for (let number = 1; number <= zoneCount + 1; number += 1) {
      if (!usedNames.has(`zone ${number}`)) return `Zone ${number}`
    }
  }

  /** @param {unknown} state Saved JSON to check before displaying it. @returns {boolean} */
  isValidState(state) {
    if (!state || state.version !== 1 || !Array.isArray(state.zones) || !this.isValidPresetState(state)) {
      return false
    }

    const crops = Array.from(this.cropTarget.options, (option) => option.value)
    const schedules = Array.from(this.scheduleTarget.options, (option) => option.value)
    const uniqueIds = new Set()
    const uniqueNames = new Set()
    const assignedSensors = new Set()

    return state.zones.every((zone) => {
      if (!zone || !Number.isSafeInteger(zone.id) || zone.id < 1 || uniqueIds.has(zone.id)) return false
      const name = zone.name ?? `Zone ${zone.id}`
      if (typeof name !== "string" || !name.trim() || name.trim().length > 60) return false
      const normalizedName = name.trim().toLowerCase()
      if (uniqueNames.has(normalizedName)) return false
      uniqueIds.add(zone.id)
      uniqueNames.add(normalizedName)
      return crops.includes(zone.crop) && schedules.includes(zone.schedule) && this.isValidSensorAssignment(zone, assignedSensors)
    })
  }

  /** @param {object} zone Restores original demo assignments for older saves. @returns {string[]} */
  sensorIdsForZone(zone) {
    return zone.sensorIds ?? DEMO_SENSORS.filter((sensor) => sensor.initialZoneId === zone.id).map((sensor) => sensor.id)
  }

  /** @param {object} zone @param {Set<string>} assigned Checks unique devices and one sensor per reading type. @returns {boolean} */
  isValidSensorAssignment(zone, assigned) {
    const ids = this.sensorIdsForZone(zone)
    if (!Array.isArray(ids)) return false
    const types = new Set()
    return ids.every((id) => {
      const sensor = DEMO_SENSORS.find((sensor) => sensor.id === id)
      if (!sensor || assigned.has(id) || types.has(sensor.type)) return false
      assigned.add(id)
      types.add(sensor.type)
      return true
    })
  }

  /** Saves current state without interrupting editing if browser storage is unavailable. */
  saveState() {
    try {
      window.localStorage.setItem(this.storageKey, JSON.stringify(this.state))
      this.showStorageNotice("")
      console.log("SUCCESS: Garden zones saved in this browser.")
    } catch (error) {
      this.showStorageNotice(this.accountIdValue
        ? "Les zones sont enregistrées sur votre compte, mais les réglages locaux n’ont pas pu être sauvegardés dans ce navigateur."
        : "Impossible d’enregistrer les modifications dans ce navigateur. Elles risquent d’être perdues en quittant ou en rechargeant la page.")
      console.warn("Garden changes could not be saved:", error)
    }
  }

  /** @param {string} message Storage feedback; an empty message hides the notice. */
  showStorageNotice(message) {
    this.storageNoticeTarget.textContent = message
    this.storageNoticeTarget.hidden = message.length === 0
  }

  /** Replaces cached zone buttons so a Turbo restoration never duplicates them. */
  renderZoneButtons() {
    this.state.zones.sort((left, right) => left.name.localeCompare(right.name, "fr", { numeric: true, sensitivity: "base" }))
    this.zoneBtnTargets.forEach((button) => button.remove())
    this.state.zones.forEach((zone) => this.appendZoneButton(zone))
  }

  /** @param {object} zone A zone with a stable numeric identifier. @returns {HTMLButtonElement} */
  appendZoneButton(zone) {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "zone-btn"
    button.textContent = zone.name
    button.dataset.gardenTarget = "zoneBtn"
    button.dataset.zoneId = String(zone.id)
    button.dataset.action = "click->garden#selectZone"
    button.setAttribute("aria-pressed", "false")
    this.zoneListTarget.insertBefore(button, this.zoneAddTarget)
    return button
  }

  /** @param {MouseEvent} event The selected zone button's click event. */
  selectZone(event) {
    if (this.zoneRequestPending) return
    const zoneId = Number(event.currentTarget.dataset.zoneId)
    if (!this.state.zones.some((zone) => zone.id === zoneId)) return

    this.state.selectedZoneId = zoneId
    this.renderSelectedZone()
    this.saveState()
    console.log(`SUCCESS: Selected Zone ${zoneId}.`)
  }

  /** Creates and selects the next numbered zone without assigning simulated sensors. */
  async addZone() {
    if (this.zoneRequestPending) return
    const nextId = this.state.nextZoneId
    if (!Number.isSafeInteger(nextId)) return

    const usedNames = new Set(this.state.zones.map((zone) => zone.name.toLowerCase()))
    const name = this.nextZoneName(usedNames, this.state.zones.length)
    const zone = { id: nextId, name, crop: "Carrots", schedule: "Every 3 days - 8:00 PM", sensorIds: [] }
    if (this.accountIdValue) {
      try {
        Object.assign(zone, await this.requestZone("POST", null, { name }))
      } catch (error) {
        this.showRequestError(error)
        return
      }
    }
    this.state.nextZoneId = zone.id + 1
    this.state.zones.push(zone)
    this.state.selectedZoneId = zone.id
    this.renderZoneButtons()
    this.renderSelectedZone()
    const button = this.zoneBtnTargets.find((button) => Number(button.dataset.zoneId) === zone.id)
    button.focus()
    this.saveState()
    console.log(`SUCCESS: Created and selected ${zone.name} (ID ${zone.id}).`)
  }

  /** @param {SubmitEvent} event Saves a trimmed, unique name for the selected zone. */
  async renameZone(event) {
    event.preventDefault()
    if (this.zoneRequestPending) return
    const zone = this.state.zones.find((zone) => zone.id === this.state.selectedZoneId)
    if (!zone) return

    const name = this.zoneNameTarget.value.trim()
    if (!name || name.length > 60) {
      this.showNameError("Saisissez un nom de zone de 1 à 60 caractères.")
      return
    }
    if (this.state.zones.some((other) => other.id !== zone.id && other.name.toLowerCase() === name.toLowerCase())) {
      this.showNameError("Une autre zone utilise déjà ce nom.")
      return
    }

    if (this.accountIdValue) {
      try {
        const saved = await this.requestZone("PATCH", zone.id, { name })
        zone.name = saved.name
      } catch (error) {
        this.showRequestError(error)
        return
      }
    } else zone.name = name
    this.renderZoneButtons()
    this.renderSelectedZone()
    this.saveState()
    console.log(`SUCCESS: Renamed Zone ${zone.id} to ${name}.`)
  }

  /** @param {string} message Explains a rejected name and focuses the field to correct it. */
  showNameError(message) {
    this.nameErrorTarget.textContent = message
    this.nameErrorTarget.hidden = false
    this.zoneNameTarget.setAttribute("aria-invalid", "true")
    this.zoneNameTarget.focus()
  }

  /** Clears name feedback when editing the field or switching to another zone. */
  clearNameError() {
    this.nameErrorTarget.hidden = true
    this.nameErrorTarget.textContent = ""
    this.zoneNameTarget.removeAttribute("aria-invalid")
  }

  /** Immediately deletes the selected zone and selects its nearest remaining neighbour. */
  async deleteZone() {
    if (this.zoneRequestPending) return
    const index = this.state.zones.findIndex((zone) => zone.id === this.state.selectedZoneId)
    const zone = this.state.zones[index]
    if (!zone) return

    if (this.accountIdValue) {
      try {
        await this.requestZone("DELETE", zone.id)
      } catch (error) {
        this.showRequestError(error)
        return
      }
    }

    this.state.zones.splice(index, 1)
    this.state.selectedZoneId = this.state.zones[Math.min(index, this.state.zones.length - 1)]?.id ?? null
    this.zoneBtnTargets.find((button) => Number(button.dataset.zoneId) === zone.id).remove()
    this.renderSelectedZone()
    const selectedButton = this.zoneBtnTargets.find((button) => Number(button.dataset.zoneId) === this.state.selectedZoneId)
    const focusTarget = selectedButton || this.zoneAddTarget
    focusTarget.focus()
    this.saveState()
    console.log(`SUCCESS: Deleted Zone ${zone.id}.`)
  }

  /** Saves the selected zone's crop and schedule when either configuration field changes. */
  async updateConfiguration() {
    const zone = this.state.zones.find((zone) => zone.id === this.state.selectedZoneId)
    if (!zone) return
    if (!await this.saveConfiguration(zone, { crop: this.cropTarget.value, schedule: this.scheduleTarget.value })) return
    this.saveState()
    console.log(`SUCCESS: Updated Zone ${zone.id} configuration.`)
  }

  /** Updates the selection, configuration and sensor display from the same zone state. */
  renderSelectedZone() {
    const zone = this.state.zones.find((zone) => zone.id === this.state.selectedZoneId)
    this.clearNameError()
    this.zoneContentTargets.forEach((content) => { content.hidden = !zone })
    this.emptyGardenTarget.hidden = Boolean(zone)
    this.localConfigurationTarget.hidden = !zone?.localConfiguration
    if (!zone) {
      this.titleTarget.textContent = "Jardin - configuration"
      this.zoneNameTarget.value = ""
      return
    }
    this.zoneBtnTargets.forEach((button) => {
      const isSelected = Number(button.dataset.zoneId) === zone.id
      button.classList.toggle("active", isSelected)
      button.setAttribute("aria-pressed", String(isSelected))
    })
    this.titleTarget.textContent = `${zone.name} - configuration`
    this.zoneNameTarget.value = zone.name
    this.cropTarget.value = zone.crop
    this.scheduleTarget.value = zone.schedule
    this.renderSensorReadings(zone)
    this.renderPresets(zone)
  }

  /** @param {object} zone Lists unassigned devices for reading types still missing in the zone. @returns {object[]} */
  availableSensors(zone) {
    const assignedIds = new Set(this.state.zones.flatMap((other) => other.sensorIds))
    const assignedTypes = new Set(DEMO_SENSORS.filter((sensor) => zone.sensorIds.includes(sensor.id)).map((sensor) => sensor.type))
    return DEMO_SENSORS.filter((sensor) => !assignedIds.has(sensor.id) && !assignedTypes.has(sensor.type))
  }

  /** Enables assignment only after an available sensor has been selected. */
  updateSensorButton() {
    this.sensorAssignTarget.disabled = !this.sensorSelectTarget.value
  }

  /** @param {SubmitEvent} event Assigns an available demo device to the active zone. */
  assignSensor(event) {
    event.preventDefault()
    const zone = this.state.zones.find((zone) => zone.id === this.state.selectedZoneId)
    if (!zone) return
    const id = this.sensorSelectTarget.value
    if (!this.availableSensors(zone).some((sensor) => sensor.id === id)) return

    zone.sensorIds.push(id)
    this.renderSensorReadings(zone)
    this.sensorSelectTarget.focus()
    this.saveState()
    console.log(`SUCCESS: Assigned sensor ${id} to Zone ${zone.id}.`)
  }

  /** @param {MouseEvent} event Removes a device from this zone, making it available elsewhere. */
  removeSensor(event) {
    const zone = this.state.zones.find((zone) => zone.id === this.state.selectedZoneId)
    const id = event.currentTarget.dataset.sensorId
    if (!zone || !zone.sensorIds.includes(id)) return

    zone.sensorIds = zone.sensorIds.filter((sensorId) => sensorId !== id)
    this.renderSensorReadings(zone)
    this.sensorSelectTarget.focus()
    this.saveState()
    console.log(`SUCCESS: Removed sensor ${id} from Zone ${zone.id}.`)
  }

  /** @param {object} sensor Creates an accessible row with a labelled health state. @returns {HTMLLIElement} */
  sensorElement(sensor) {
    const item = document.createElement("li")
    item.className = "sensor-item"
    const name = document.createElement("span")
    name.className = "sensor-name"
    name.textContent = sensor.name
    const health = document.createElement("span")
    health.className = `sensor-health ${sensor.health}`
    health.textContent = SENSOR_HEALTH[sensor.health]
    const remove = document.createElement("button")
    remove.type = "button"
    remove.className = "sensor-remove"
    remove.textContent = "×"
    remove.setAttribute("aria-label", `Retirer ${sensor.name}`)
    remove.dataset.sensorId = sensor.id
    remove.dataset.action = "click->garden#removeSensor"
    item.append(name, health, remove)
    return item
  }

  /** @param {object} zone Displays device assignments, simulated health and available demo readings. */
  renderSensorReadings(zone) {
    const sensors = DEMO_SENSORS.filter((sensor) => zone.sensorIds.includes(sensor.id))
    this.sensorTagsTarget.replaceChildren(...sensors.map((sensor) => this.sensorElement(sensor)))
    this.sensorTagsTarget.hidden = sensors.length === 0
    this.emptySensorsTarget.hidden = sensors.length > 0
    this.readingsNoteTarget.textContent = sensors.length > 0
      ? "Mesures simulées pour cette zone de démonstration."
      : "Aucune mesure disponible."
    const available = this.availableSensors(zone)
    this.sensorSelectTarget.replaceChildren(new Option(available.length ? "Choisir un capteur" : "Aucun capteur disponible", ""))
    available.forEach((sensor) => this.sensorSelectTarget.add(new Option(sensor.name, sensor.id)))
    this.sensorSelectTarget.disabled = available.length === 0
    this.updateSensorButton()
    for (const type of ["temp", "humidity", "brightness"]) {
      const sensor = sensors.find((sensor) => sensor.type === type)
      this[`${type}Target`].textContent = sensor?.health === "offline" ? "—" : sensor?.reading ?? "—"
    }
  }

  /** Upgrades older saves without changing their zones or sensor assignments. */
  initializePresets() {
    this.state.presets ??= []
    const highestId = this.state.presets.reduce((highest, preset) => Math.max(highest, preset.id), 0)
    this.state.nextPresetId = Math.max(highestId + 1, Number.isSafeInteger(this.state.nextPresetId) ? this.state.nextPresetId : 1)
    this.state.zones.forEach((zone) => {
      zone.thresholds ??= this.emptyThresholds()
      if (!this.state.presets.some((preset) => preset.id === zone.presetId)) zone.presetId = null
    })
  }

  /** @returns {object} Blank thresholds disable all three settings. */
  emptyThresholds() {
    return { humidity: null, temperature: null, brightness: null }
  }

  /** @param {unknown} values Checks stored units and numeric bounds. @returns {boolean} */
  validThresholds(values) {
    const bounds = { humidity: [0, 100], temperature: [-50, 100], brightness: [0, 200000] }
    return Boolean(values && Object.entries(bounds).every(([key, [min, max]]) =>
      values[key] === null || (typeof values[key] === "number" && Number.isFinite(values[key]) && values[key] >= min && values[key] <= max)))
  }

  /** @param {object} state Accepts legacy saves and checks the optional preset library. @returns {boolean} */
  isValidPresetState(state) {
    const presets = state.presets ?? []
    if (!Array.isArray(presets)) return false
    const ids = new Set()
    const names = new Set()
    const validPresets = presets.every((preset) => {
      if (!preset || !Number.isSafeInteger(preset.id) || preset.id < 1 || ids.has(preset.id)) return false
      if (typeof preset.name !== "string" || !preset.name.trim() || preset.name.length > 60) return false
      const name = preset.name.trim().toLowerCase()
      if (names.has(name) || !this.validThresholds(preset.thresholds)) return false
      if (Object.values(preset.thresholds).every((value) => value === null)) return false
      ids.add(preset.id)
      names.add(name)
      return true
    })
    return validPresets && state.zones.every((zone) => zone && (zone.thresholds === undefined || this.validThresholds(zone.thresholds)))
  }

  /** @returns {object|null} Current field values, or inline feedback for invalid input. */
  readThresholds() {
    const values = {}
    for (const key of ["humidity", "temperature", "brightness"]) {
      const field = this[`${key}ThresholdTarget`]
      if (!field.checkValidity()) {
        this.showPresetError("Vérifiez les plages des seuils et saisissez des nombres valides.")
        return null
      }
      values[key] = field.value === "" ? null : Number(field.value)
    }
    if (!this.validThresholds(values)) return null
    return values
  }

  /** Saves manual threshold changes only to the active zone. */
  async updateThresholds() {
    const zone = this.state.zones.find((zone) => zone.id === this.state.selectedZoneId)
    const thresholds = this.readThresholds()
    if (!zone || !thresholds) return
    if (!await this.saveConfiguration(zone, { thresholds, presetId: null })) return
    this.showPresetError("")
    this.saveState()
    console.log(`SUCCESS: Updated Zone ${zone.id} thresholds.`)
  }

  /** @param {object} zone Restores its values and lists reusable presets safely as text. */
  renderPresets(zone) {
    zone.thresholds ??= this.emptyThresholds()
    this.presetSelectTarget.replaceChildren(new Option("Choisir un préréglage", ""))
    this.state.presets.forEach((preset) => this.presetSelectTarget.add(new Option(preset.name, preset.id)))
    this.presetSelectTarget.value = zone.presetId ?? ""
    for (const key of ["humidity", "temperature", "brightness"]) {
      this[`${key}ThresholdTarget`].value = zone.thresholds[key] ?? ""
    }
    this.selectPreset()
    this.showPresetError("")
  }

  /** Selects a library entry for applying, editing or deleting without changing zone values. */
  selectPreset() {
    const preset = this.state.presets.find((preset) => preset.id === Number(this.presetSelectTarget.value))
    this.presetNameTarget.value = preset?.name ?? ""
    this.presetApplyTarget.disabled = !preset
    this.presetUpdateTarget.disabled = !preset
    this.presetDeleteTarget.disabled = !preset
  }

  /** Copies the chosen preset into the active zone; other zones keep their own snapshots. */
  async applyPreset() {
    const zone = this.state.zones.find((zone) => zone.id === this.state.selectedZoneId)
    const preset = this.state.presets.find((preset) => preset.id === Number(this.presetSelectTarget.value))
    if (!zone || !preset) return
    if (!await this.saveConfiguration(zone, { thresholds: { ...preset.thresholds }, presetId: preset.id })) return
    this.renderPresets(zone)
    this.saveState()
    console.log(`SUCCESS: Applied preset ${preset.id} to Zone ${zone.id}.`)
  }

  /** Creates a named preset from the currently displayed thresholds. */
  createPreset() {
    this.savePreset(false)
  }

  /** Updates the selected library entry from the currently displayed thresholds. */
  updatePreset() {
    this.savePreset(true)
  }

  /** @param {boolean} updating Validates the editor before creating or updating a library entry. */
  async savePreset(updating) {
    const zone = this.state.zones.find((zone) => zone.id === this.state.selectedZoneId)
    if (!zone) return
    const existing = updating ? this.state.presets.find((preset) => preset.id === Number(this.presetSelectTarget.value)) : null
    if (updating && !existing) return
    const name = this.presetNameTarget.value.trim()
    const thresholds = this.readThresholds()
    if (!thresholds) return
    if (!name || name.length > 60) return this.showPresetError("Saisissez un nom de préréglage de 1 à 60 caractères.")
    if (this.state.presets.some((preset) => preset.id !== existing?.id && preset.name.toLowerCase() === name.toLowerCase())) {
      return this.showPresetError("Un autre préréglage utilise déjà ce nom.")
    }
    if (Object.values(thresholds).every((value) => value === null)) return this.showPresetError("Saisissez au moins un seuil pour enregistrer un préréglage.")
    const id = existing?.id ?? this.state.nextPresetId
    if (!Number.isSafeInteger(id)) return
    if (!await this.saveConfiguration(zone, { thresholds: { ...thresholds }, presetId: id })) return
    if (existing) Object.assign(existing, { name, thresholds: { ...thresholds } })
    else {
      this.state.presets.push({ id, name, thresholds: { ...thresholds } })
      this.state.nextPresetId = id + 1
    }
    this.renderPresets(zone)
    this.saveState()
    console.log(`SUCCESS: Saved preset ${id}.`)
  }

  /** Removes the selected preset while retaining every zone's applied thresholds. */
  deletePreset() {
    const id = Number(this.presetSelectTarget.value)
    if (!this.state.presets.some((preset) => preset.id === id)) return
    this.state.presets = this.state.presets.filter((preset) => preset.id !== id)
    this.state.zones.forEach((zone) => { if (zone.presetId === id) zone.presetId = null })
    this.renderPresets(this.state.zones.find((zone) => zone.id === this.state.selectedZoneId))
    this.saveState()
    console.log(`SUCCESS: Deleted preset ${id}.`)
  }

  /** @param {string} message Shows inline validation feedback without opening a dialog. */
  showPresetError(message) {
    this.presetErrorTarget.textContent = message
    this.presetErrorTarget.hidden = !message
  }
}

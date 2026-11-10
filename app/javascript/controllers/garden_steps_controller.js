import { Controller } from "@hotwired/stimulus"

/** Reveals one part of the garden at a time, retaining fields when moving between steps. */
export default class extends Controller {
  static targets = ["panel", "button", "previous", "next", "progress"]

  connect() {
    this.step = 1
    this.changing = false
    this.render()
  }

  select(event) {
    this.goTo(Number(event.currentTarget.dataset.step))
  }

  previous() {
    this.goTo(this.step - 1)
  }

  next() {
    this.goTo(this.step + 1)
  }

  async goTo(step) {
    if (this.changing || step === this.step || step < 1 || step > this.panelTargets.length) return
    this.changing = true
    try {
      const pending = []
      this.dispatch("before-change", { detail: { from: this.step, to: step, waitUntil: (task) => pending.push(task) } })
      if ((await Promise.all(pending)).some((result) => result === false) || !this.element.isConnected) return
      this.step = step
      this.render()
      this.panelTargets[step - 1].querySelector("h2").focus({ preventScroll: true })
      this.element.scrollIntoView({ block: "start", behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "instant" : "smooth" })
    } finally {
      this.changing = false
    }
  }

  render() {
    const labels = ["Cultures", "Capteurs", "Arrosage", "Seuils"]
    this.panelTargets.forEach((panel, index) => { panel.hidden = index + 1 !== this.step })
    this.buttonTargets.forEach((button, index) => {
      if (index + 1 === this.step) button.setAttribute("aria-current", "step")
      else button.removeAttribute("aria-current")
      button.classList.toggle("is-past", index + 1 < this.step)
    })
    this.progressTarget.textContent = `Étape ${this.step} sur ${this.panelTargets.length} · ${labels[this.step - 1]}`
    this.previousTarget.disabled = this.step === 1
    this.nextTarget.hidden = this.step === this.panelTargets.length
    this.nextTarget.textContent = ["Continuer vers les capteurs →", "Continuer vers l’arrosage →", "Enregistrer et continuer →"][this.step - 1] ?? ""
  }
}

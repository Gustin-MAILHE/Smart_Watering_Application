import { Controller } from "@hotwired/stimulus"

/** Keeps native form validation in French, independently of the browser language. */
export default class extends Controller {
  static targets = ["password", "visibilityButton"]

  toggleVisibility() {
    const visible = this.passwordTargets[0]?.type === "password"
    this.passwordTargets.forEach((field) => { field.type = visible ? "text" : "password" })
    this.visibilityButtonTarget.textContent = visible ? "Masquer les mots de passe" : "Afficher les mots de passe"
    this.visibilityButtonTarget.setAttribute("aria-pressed", String(visible))
  }

  validate(event) {
    const field = event.target
    field.setCustomValidity("")
    if (field.validity.valueMissing) {
      field.setCustomValidity(field.type === "email"
        ? "Saisissez votre adresse e-mail."
        : field.autocomplete === "new-password" && field.name.endsWith("[password_confirmation]")
          ? "Confirmez votre nouveau mot de passe."
          : "Saisissez votre nouveau mot de passe.")
    } else if (field.validity.typeMismatch && field.type === "email") {
      field.setCustomValidity("Saisissez une adresse e-mail valide, par exemple nom@exemple.fr.")
    } else if (field.validity.tooShort) {
      field.setCustomValidity(`Le mot de passe doit contenir au moins ${field.minLength} caractères.`)
    }
  }

  clear(event) {
    event.target.setCustomValidity("")
  }
}

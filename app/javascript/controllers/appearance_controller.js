import { Controller } from "@hotwired/stimulus"

const THEME_KEY = "smartWatering.theme"

/** Controls the shared theme and back-to-top button across Turbo visits. */
export default class extends Controller {
  static targets = ["toggle", "sun", "moon", "backToTop"]

  /** Restores preferences when the shared layout connects. */
  connect() {
    this.refresh()
  }

  /** Restores theme and scroll visibility after Turbo rendering. */
  refresh() {
    let theme = document.documentElement.dataset.theme || "dark"
    try {
      const saved = window.localStorage.getItem(THEME_KEY)
      if (["light", "dark"].includes(saved)) theme = saved
    } catch (_) { /* Keep the current theme when browser storage is blocked. */ }
    this.applyTheme(theme)
    cancelAnimationFrame(this.scrollFrame)
    this.scrollFrame = requestAnimationFrame(() => this.updateScroll())
  }

  /** Cancels pending work when Turbo disconnects this layout. */
  disconnect() {
    cancelAnimationFrame(this.scrollFrame)
  }

  /** Changes the theme and saves an explicit user preference. */
  toggleTheme() {
    const theme = document.documentElement.dataset.theme === "dark" ? "light" : "dark"
    this.applyTheme(theme)
    try {
      window.localStorage.setItem(THEME_KEY, theme)
    } catch (_) { /* Theme switching still works without persistence. */ }
  }

  /** @param {string} theme Updates CSS variables and the button's accessible action. */
  applyTheme(theme) {
    const dark = theme === "dark"
    document.documentElement.dataset.theme = dark ? "dark" : "light"
    document.documentElement.style.colorScheme = dark ? "dark" : "light"
    this.sunTarget.toggleAttribute("hidden", dark)
    this.moonTarget.toggleAttribute("hidden", !dark)
    const label = dark ? "Passer en mode jour" : "Passer en mode nuit"
    this.toggleTarget.setAttribute("aria-label", label)
    this.toggleTarget.title = label
  }

  /** Shows the return button only after leaving the top of the page. */
  updateScroll() {
    this.backToTopTarget.hidden = window.scrollY < 240
  }

  /** Scrolls up while respecting reduced-motion preferences. */
  scrollToTop() {
    document.querySelector(".site-header__title")?.focus({ preventScroll: true })
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    window.scrollTo({ top: 0, behavior: reducedMotion ? "auto" : "smooth" })
  }
}

import { Controller } from "@hotwired/stimulus";

const THEME_KEY = "smartWatering.theme";

export default class extends Controller {
  static targets = ["toggle", "sun", "moon", "themeLabel", "backToTop", "themeSelect"];

  connect() {
    this.refresh();
  }

  refresh() {
    let theme = 'default';
    try {
      const saved = window.localStorage.getItem(THEME_KEY)
      if (["light", "dark", "sakura", "default"].includes(saved)) {
        theme = saved;
      }
    } catch (_) { }
    this.applyTheme(theme);
    cancelAnimationFrame(this.scrollFrame);
    this.scrollFrame = requestAnimationFrame(() => this.updateScroll());
  }

  disconnect() {
    cancelAnimationFrame(this.scrollFrame);
  }

  toggleTheme() {
    const current = document.documentElement.dataset.theme;

    const isCurrentlyDark = ["dark", "default"].includes(current);
    const newTheme = isCurrentlyDark ? "light" : "dark";

    this.saveTheme(newTheme);
  }

  changeThemeFromSelect(event) {
    this.saveTheme(event.target.value);
  }

  saveTheme(theme) {
    try {
      window.localStorage.setItem(THEME_KEY, theme);
    } catch (_) { }
    this.applyTheme(theme);
  }

  applyTheme(theme) {

    const activeTheme = theme;
    const isDark = ["dark", "default"].includes(activeTheme);

    // apply html theme
    document.documentElement.dataset.theme = activeTheme;
    document.documentElement.style.colorScheme = isDark ? "dark" : "light";

    if (this.hasSunTarget && this.hasMoonTarget) {
      this.sunTarget.toggleAttribute("hidden", isDark);
      this.moonTarget.toggleAttribute("hidden", !isDark);

      if (this.hasThemeLabelTarget) {
        const dayText = this.themeLabelTarget.dataset.dayText;
        const nightText = this.themeLabelTarget.dataset.nightText;
        this.themeLabelTarget.textContent = isDark ? nightText : dayText;
      }

      if (this.hasToggleTarget) {
        const label = isDark ? "Passer en mode jour" : "Passer en mode nuit";
        this.toggleTarget.setAttribute("aria-label", label);
        this.toggleTarget.title = label;
      }
    }

    // sync select menu
    if (this.hasThemeSelectTarget) {
      this.themeSelectTarget.value = theme;
    }
  }

  updateScroll() {
    if (this.hasBackToTopTarget) {
      this.backToTopTarget.hidden = window.scrollY < 240
    }
  }

  scrollToTop() {
    document.querySelector(".site-header__title")?.focus({ preventScroll: true });
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    window.scrollTo({ top: 0, behavior: reducedMotion ? "auto" : "smooth"});
  }

}
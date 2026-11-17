import { Controller } from "@hotwired/stimulus";

const THEME_KEY = "smartWatering.theme";

export default class extends Controller {
  static targets = ["backToTop", "themeSelect"];

  connect() {
    this.refresh();
  }

  refresh() {
    let theme = "default";
    try {
      const saved = window.localStorage.getItem(THEME_KEY);
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
    const isDark = ["dark", "default"].includes(theme);

    document.documentElement.dataset.theme = theme;
    document.documentElement.style.colorScheme = isDark ? "dark" : "light";

    if (this.hasThemeSelectTarget) {
      this.themeSelectTarget.value = theme;
    }
  }

  updateScroll() {
    if (this.hasBackToTopTarget) {
      this.backToTopTarget.hidden = window.scrollY < 240;
    }
  }

  scrollToTop() {
    document.querySelector(".site-header__title")?.focus({ preventScroll: true });
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    window.scrollTo({ top: 0, behavior: reducedMotion ? "auto" : "smooth" });
  }
}

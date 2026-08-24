import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "quitando.theme"
const THEMES = [ "system", "light", "dark" ]

export default class extends Controller {
  connect() {
    const theme = document.documentElement.dataset.theme
    this.element.value = THEMES.includes(theme) ? theme : "system"
  }

  change() {
    const theme = THEMES.includes(this.element.value) ? this.element.value : "system"
    document.documentElement.dataset.theme = theme

    if (theme === "system") {
      localStorage.removeItem(STORAGE_KEY)
    } else {
      localStorage.setItem(STORAGE_KEY, theme)
    }
  }
}

import { Controller } from "@hotwired/stimulus"

// Content stays visible until observed; motion never gates access to the page.
export default class extends Controller {
  static targets = ["item"]

  connect() {
    this.preference = window.matchMedia("(prefers-reduced-motion: reduce)")
    this.configure = this.configure.bind(this)
    this.beforeCache = this.stop.bind(this)
    this.preference.addEventListener("change", this.configure)
    document.addEventListener("turbo:before-cache", this.beforeCache)
    this.configure()
  }

  configure() {
    this.stop()
    if (this.preference.matches || !("IntersectionObserver" in window)) return

    this.element.classList.add("motion-enabled")
    this.observer = new IntersectionObserver(entries => {
      for (const entry of entries) {
        if (!entry.isIntersecting) continue
        entry.target.dataset.revealed = "true"
        entry.target.classList.add("reveal-enter")
        this.observer.unobserve(entry.target)
      }
    }, { threshold: 0.08 })
    for (const item of this.itemTargets) {
      if (item.dataset.revealed !== "true") this.observer.observe(item)
    }
  }

  stop() {
    this.observer?.disconnect()
    this.element.classList.remove("motion-enabled")
    for (const item of this.itemTargets) item.classList.remove("reveal-enter")
  }

  disconnect() {
    this.stop()
    this.preference.removeEventListener("change", this.configure)
    document.removeEventListener("turbo:before-cache", this.beforeCache)
  }
}

import { Controller } from "@hotwired/stimulus"

// Owns the native dialog around the permanent Turbo Frame without storing form state in JavaScript.
export default class extends Controller {
  connect() {
    this.frame = this.element.querySelector("turbo-frame#group_dialog")
    this.onFrameLoad = this.frameLoaded.bind(this)
    this.onClose = this.restoreFocus.bind(this)
    this.onTurboClick = this.captureOpener.bind(this)
    this.frame?.addEventListener("turbo:frame-load", this.onFrameLoad)
    this.element.addEventListener("close", this.onClose)
    document.addEventListener("turbo:click", this.onTurboClick)
  }

  disconnect() {
    this.frame?.removeEventListener("turbo:frame-load", this.onFrameLoad)
    this.element.removeEventListener("close", this.onClose)
    document.removeEventListener("turbo:click", this.onTurboClick)
    cancelAnimationFrame(this.focusFrame)
  }

  close() {
    this.element.close()
    this.frame?.replaceChildren()
  }

  frameLoaded() {
    if (this.frame?.children.length === 0) return this.close()

    this.returnFocus ||= document.activeElement
    if (!this.element.open) this.element.showModal()
    cancelAnimationFrame(this.focusFrame)
    this.focusFrame = requestAnimationFrame(() => {
      if (!this.element.open) return

      const initialFocus = this.frame.querySelector("[autofocus]") ||
        this.frame.querySelector("input, select, textarea, button")
      initialFocus?.focus()
    })
  }

  restoreFocus() {
    this.returnFocus?.focus?.()
    this.returnFocus = null
  }

  captureOpener(event) {
    const opener = event.target.closest("[data-turbo-frame='group_dialog']")
    if (opener) this.returnFocus = opener
  }
}

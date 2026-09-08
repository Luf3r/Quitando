import { Controller } from "@hotwired/stimulus"

// A preview is authoritative only for the exact form state that produced it.
// It never recomputes shares in the browser.
export default class extends Controller {
  static targets = [ "revision", "preview", "message" ]

  connect() {
    this.onPreviewLoad = this.previewLoaded.bind(this)
    this.frame = this.previewTarget.querySelector("turbo-frame")
    this.frame?.addEventListener("turbo:frame-load", this.onPreviewLoad)
  }

  disconnect() {
    this.frame?.removeEventListener("turbo:frame-load", this.onPreviewLoad)
  }

  invalidate(event) {
    if (event.target === this.revisionTarget) return

    this.revisionTarget.value = String(Number(this.revisionTarget.value) + 1)
    this.messageTarget.hidden = false
    this.disableConfirmation()
  }

  previewLoaded(event) {
    const preview = event.target
    const revision = preview.querySelector("[data-preview-guard-revision-value]")?.dataset.previewGuardRevisionValue
    if (revision !== this.revisionTarget.value) {
      this.messageTarget.hidden = false
      this.disableConfirmation(preview)
      return
    }

    this.messageTarget.hidden = true
    preview.querySelector("[data-preview-guard-target='confirmation']")?.focus()
  }

  disableConfirmation(preview = this.frame) {
    preview.querySelector("[data-preview-guard-target='confirmation']")?.setAttribute("disabled", "disabled")
  }
}

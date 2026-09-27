import { Controller } from "@hotwired/stimulus"

// Reports Action Cable degradation without treating a WebSocket as the source of truth.
export default class extends Controller {
  connect() {
    this.stream = this.element.querySelector("turbo-cable-stream-source")
    if (!this.stream) return

    this.hasConnected = this.stream.hasAttribute("connected")
    this.observer = new MutationObserver(this.connectionChanged)
    this.observer.observe(this.stream, { attributes: true, attributeFilter: [ "connected" ] })

    if (!this.hasConnected) this.startInitialConnectionTimer()
  }

  disconnect() {
    this.observer?.disconnect()
    this.observer = null
    this.clearInitialConnectionTimer()
  }

  connectionChanged = () => {
    const connected = this.stream.hasAttribute("connected")

    if (connected) {
      this.hasConnected = true
      this.clearInitialConnectionTimer()
      return
    }

    if (this.hasConnected) this.reportDegradation()
  }

  startInitialConnectionTimer() {
    this.initialConnectionTimer = setTimeout(() => {
      if (!this.stream?.hasAttribute("connected")) this.reportDegradation()
    }, 5000)
  }

  clearInitialConnectionTimer() {
    clearTimeout(this.initialConnectionTimer)
    this.initialConnectionTimer = null
  }

  reportDegradation() {
    const notice = document.getElementById("group_remote_notice")
    if (notice) notice.textContent = "Atualizações em tempo real indisponíveis. Recarregue a página para conferir o estado atual."

    this.element.dispatchEvent(new CustomEvent("group-realtime-status:degraded", { bubbles: true }))
    console.warn("Group real-time connection unavailable; HTTP reload remains the reconciliation source.")
  }
}

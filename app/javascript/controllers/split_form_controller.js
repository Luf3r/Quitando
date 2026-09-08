import { Controller } from "@hotwired/stimulus"

// Presentation only: the submitted split_type remains the server authority.
export default class extends Controller {
  static targets = [ "equal", "exact" ]

  connect() {
    this.update()
  }

  update() {
    const splitType = this.element.querySelector('input[name$="[split_type]"]:checked')?.value
    this.equalTarget.hidden = splitType === "exact"
    this.exactTarget.hidden = splitType !== "exact"
  }
}

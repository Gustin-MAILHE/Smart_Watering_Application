import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="drawer"
export default class extends Controller {
  static targets = ["drawer"]

  open() {
    this.drawerTarget.show()
  }
  connect() {
  }
}

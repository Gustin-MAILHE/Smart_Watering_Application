import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="drawer"
export default class extends Controller {
  static targets = ["drawer"]

  open() {
    console.log("Clic détecté !", this.drawerTarget)
    this.drawerTarget.show()
  }
  connect() {
  }
}

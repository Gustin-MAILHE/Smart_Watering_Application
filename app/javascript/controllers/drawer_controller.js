import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer"]

  open() {
    this.drawerTarget.show()
  }
}

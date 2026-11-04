import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["title", "tabs", "panels", "hint", "tabTemplate", "panelTemplate"]

    connect() {
        this.count = 0
        this.select(null)
    }

    add() {
        this.count += 1
        const number = this.count

        const tab = this.tabTemplateTarget.content.firstElementChild.cloneNode(true)
        tab.textContent = `Zone ${number}`
        tab.dataset.zone = number
        this.tabsTarget.insertBefore(tab, this.tabsTarget.lastElementChild)

        const panel = this.panelTemplateTarget.content.firstElementChild.cloneNode(true)
        panel.dataset.zone = number
        this.panelsTarget.append(panel)

        this.select(number)
    }

    show(event) {
        this.select(Number(event.currentTarget.dataset.zone))
    }

    select(number) {
        this.tabsTarget.querySelectorAll("[data-zone]").forEach((tab) => {
            tab.classList.toggle("zone-tabs__tab--active", Number(tab.dataset.zone) === number)
        })

        this.panelsTarget.querySelectorAll("[data-zone]").forEach((panel) => {
            panel.hidden = Number(panel.dataset.zone) !== number
        })

        this.titleTarget.textContent = number ? `Zone ${number} - configuration` : "Configuration du jardin"
        this.hintTarget.hidden = number !== null
    }
}
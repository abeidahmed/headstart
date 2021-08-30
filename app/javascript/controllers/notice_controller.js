export default class extends ApplicationController {
  hide(event) {
    event.preventDefault()
    this.element.remove()
  }
}

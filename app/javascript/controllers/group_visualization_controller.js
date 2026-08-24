import { Controller } from "@hotwired/stimulus"

// Draws the server-owned visualization payload without calculating financial values.
export default class extends Controller {
  static targets = [ "controls", "currentLayer", "graph", "live", "status" ]
  static values = {
    payload: Object,
    unavailableMessage: String,
    emptyMessage: String,
    layerNames: Object,
    announcements: Object
  }

  connect() {
    this.connected = true
    this.loadRenderer()
  }

  disconnect() {
    this.connected = false
  }

  async loadRenderer() {
    try {
      const { select } = await import("d3-selection")
      if (!this.connected || !this.element.isConnected) return

      this.select = select
      this.draw()
    } catch (error) {
      if (this.connected && this.element.isConnected) this.renderUnavailable(error)
    }
  }

  payloadValueChanged() {
    if (!this.connected) return

    requestAnimationFrame(() => {
      if (this.connected && this.element.isConnected) this.draw()
    })
  }

  draw() {
    try {
      const payload = this.validatedPayload()
      const layer = this.availableLayer(payload)

      this.graphTarget.replaceChildren()
      this.element.removeAttribute("data-visualization-unavailable")
      this.liveTarget.textContent = ""
      if (!layer) {
        this.controlsTarget.hidden = true
        this.currentLayerTarget.textContent = ""
        this.showAllTables()
        return this.showEmptyState()
      }

      this.selectedLayer = layer
      this.configureControls(layer)
      this.showSelectedTable(layer)
      this.drawLayer(payload, layer)
    } catch (error) {
      this.renderUnavailable(error)
    }
  }

  selectLayer(event) {
    const layer = event.target.value

    try {
      const payload = this.validatedPayload()
      if (![ "historical", "bilateral", "plan" ].includes(layer)) {
        throw new TypeError("Visualization selected layer is malformed")
      }

      this.selectedLayer = layer
      this.userSelectedLayer = layer
      this.showSelectedTable(layer)
      this.drawLayer(payload, layer)
      this.liveTarget.textContent = this.announcementsValue[layer]
    } catch (error) {
      this.renderUnavailable(error)
    }
  }

  validatedPayload() {
    const payload = this.payloadValue
    if (!payload || !Array.isArray(payload.nodes) || !payload.layers || typeof payload.layers !== "object") {
      throw new TypeError("Visualization payload must contain nodes and layers")
    }

    const nodeIds = new Set()
    payload.nodes.forEach((node) => {
      if (typeof node.user_id !== "string" || typeof node.label !== "string" || !Number.isInteger(node.position)) {
        throw new TypeError("Visualization node is malformed")
      }
      nodeIds.add(node.user_id)
    })

    for (const layer of [ "historical", "bilateral", "plan" ]) {
      if (!Array.isArray(payload.layers[layer])) throw new TypeError(`Visualization layer ${layer} is malformed`)

      payload.layers[layer].forEach((edge) => {
        const validEdge = nodeIds.has(edge.from_user_id) &&
          nodeIds.has(edge.to_user_id) &&
          typeof edge.amount_cents === "string" &&
          /^[1-9]\d*$/.test(edge.amount_cents) &&
          typeof edge.formatted_amount === "string"
        if (!validEdge) throw new TypeError(`Visualization edge in ${layer} is malformed`)
      })
    }

    if (payload.initial_layer !== null && ![ "historical", "bilateral", "plan" ].includes(payload.initial_layer)) {
      throw new TypeError("Visualization initial layer is malformed")
    }

    return payload
  }

  renderSvg(nodes, edges, layer) {
    const width = 840
    const height = 480
    const centerX = width / 2
    const centerY = height / 2
    const radius = 170
    const sortedNodes = nodes.toSorted((left, right) =>
      left.position - right.position || left.user_id.localeCompare(right.user_id)
    )
    const positionedNodes = sortedNodes.map((node, index) => {
      const angle = ((Math.PI * 2 * index) / sortedNodes.length) - (Math.PI / 2)
      return {
        ...node,
        x: centerX + (Math.cos(angle) * radius),
        y: centerY + (Math.sin(angle) * radius)
      }
    })
    const nodeById = new Map(positionedNodes.map((node) => [ node.user_id, node ]))
    const svg = this.select(this.graphTarget)
      .append("svg")
      .attr("data-visualization-graph", "")
      .attr("data-layer", layer)
      .attr("viewBox", `0 0 ${width} ${height}`)
      .attr("role", "presentation")
      .attr("aria-hidden", "true")
      .attr("focusable", "false")

    const markerId = `visualization-arrow-${this.element.id}`
    svg.append("defs")
      .append("marker")
      .attr("id", markerId)
      .attr("markerWidth", 8)
      .attr("markerHeight", 8)
      .attr("refX", 7)
      .attr("refY", 4)
      .attr("orient", "auto")
      .append("path")
      .attr("d", "M0,0 L8,4 L0,8 Z")
      .attr("class", "visualization-arrow")

    const edgeGeometry = edges.map((edge) => this.edgeGeometry(edge, nodeById))
    const edgeGroup = svg.append("g").attr("class", `visualization-edges visualization-edges--${layer}`)
    edgeGroup.selectAll("path")
      .data(edgeGeometry)
      .join("path")
      .attr("data-from-user-id", (item) => item.edge.from_user_id)
      .attr("data-to-user-id", (item) => item.edge.to_user_id)
      .attr("d", (item) => item.path)
      .attr("class", "visualization-edge")
      .attr("marker-end", `url(#${markerId})`)

    edgeGroup.selectAll("text")
      .data(edgeGeometry)
      .join("text")
      .attr("data-edge-label", "")
      .attr("x", (item) => item.labelX)
      .attr("y", (item) => item.labelY)
      .attr("class", "visualization-edge-label")
      .text((item) => item.edge.formatted_amount)

    const nodeGroup = svg.append("g").attr("class", "visualization-nodes")
    const renderedNodes = nodeGroup.selectAll("g")
      .data(positionedNodes)
      .join("g")
      .attr("transform", (node) => `translate(${node.x},${node.y})`)

    renderedNodes.append("circle")
      .attr("data-user-id", (node) => node.user_id)
      .attr("r", 30)
      .attr("class", "visualization-node")

    renderedNodes.append("text")
      .attr("class", "visualization-node-label")
      .attr("text-anchor", "middle")
      .attr("dy", 48)
      .text((node) => node.label)
  }

  availableLayer(payload) {
    if (this.userSelectedLayer && Object.hasOwn(payload.layers, this.userSelectedLayer)) return this.userSelectedLayer

    return payload.initial_layer
  }

  configureControls(layer) {
    this.controlsTarget.hidden = false
    this.controlsTarget.querySelectorAll("input[type='radio']").forEach((input) => {
      input.checked = input.value === layer
    })
  }

  drawLayer(payload, layer) {
    const edges = payload.layers[layer]
    this.graphTarget.replaceChildren()
    this.currentLayerTarget.textContent = this.layerNamesValue[layer]
    if (edges.length === 0) return this.showEmptyState()

    this.statusTarget.hidden = true
    this.renderSvg(payload.nodes, edges, layer)
  }

  showSelectedTable(layer) {
    this.element.querySelectorAll("[data-visualization-layer-panel]").forEach((panel) => {
      panel.hidden = panel.dataset.visualizationLayerPanel !== layer
    })
  }

  showAllTables() {
    this.element.querySelectorAll("[data-visualization-layer-panel]").forEach((panel) => {
      panel.hidden = false
    })
  }

  edgeGeometry(edge, nodeById) {
    const from = nodeById.get(edge.from_user_id)
    const to = nodeById.get(edge.to_user_id)
    const dx = to.x - from.x
    const dy = to.y - from.y
    const distance = Math.hypot(dx, dy) || 1
    const unitX = dx / distance
    const unitY = dy / distance
    const startX = from.x + (unitX * 32)
    const startY = from.y + (unitY * 32)
    const endX = to.x - (unitX * 38)
    const endY = to.y - (unitY * 38)
    const controlX = ((startX + endX) / 2) - (unitY * 28)
    const controlY = ((startY + endY) / 2) + (unitX * 28)

    return {
      edge,
      path: `M ${startX} ${startY} Q ${controlX} ${controlY} ${endX} ${endY}`,
      labelX: (startX + (2 * controlX) + endX) / 4,
      labelY: ((startY + (2 * controlY) + endY) / 4) - 8
    }
  }

  showEmptyState() {
    this.statusTarget.textContent = this.emptyMessageValue
    this.statusTarget.hidden = false
  }

  renderUnavailable(error) {
    this.graphTarget.replaceChildren()
    this.element.setAttribute("data-visualization-unavailable", "true")
    this.controlsTarget.hidden = true
    this.currentLayerTarget.textContent = ""
    this.liveTarget.textContent = ""
    this.showAllTables()
    this.statusTarget.textContent = this.unavailableMessageValue
    this.statusTarget.hidden = false
    console.error("Group visualization unavailable", error)
  }
}

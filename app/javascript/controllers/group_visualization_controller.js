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
      if (typeof node.user_id !== "string" ||
          typeof node.short_label !== "string" || node.short_label.trim().length === 0 ||
          typeof node.full_name !== "string" || node.full_name.trim().length === 0 ||
          !Number.isInteger(node.position)) {
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

    const labelGroups = edgeGroup.selectAll("g[data-edge-label]")
      .data(edgeGeometry)
      .join("g")
      .attr("data-edge-label", "")
      .attr("class", "visualization-edge-label")

    labelGroups.selectAll("text")
      .data((item) => [ item ])
      .join("text")
      .attr("data-edge-label", "")
      .attr("class", "visualization-edge-label__text")
      .attr("text-anchor", "middle")
      .attr("dominant-baseline", "middle")
      .text((item) => item.edge.formatted_amount)

    const placedLabels = this.placeEdgeLabels(labelGroups.nodes().map((node, index) => {
      const bounds = node.querySelector("text").getBBox()
      return { ...edgeGeometry[index], width: bounds.width + 12, height: bounds.height + 8 }
    }))

    labelGroups.data(placedLabels)
      .attr("transform", (item) => `translate(${item.labelX},${item.labelY})`)
      .attr("data-edge-label-anchored", (item) => String(item.offset === 0))
      .each((item, index, nodes) => {
        const group = this.select(nodes[index])
        group.selectAll("line[data-edge-label-connector]")
          .data(item.offset === 0 ? [] : [ item ])
          .join("line")
          .attr("data-edge-label-connector", "")
          .attr("class", "visualization-edge-label__connector")
          .attr("x1", (label) => label.anchorX - label.labelX)
          .attr("y1", (label) => label.anchorY - label.labelY)
          .attr("x2", 0)
          .attr("y2", 0)

        group.selectAll("rect")
          .data([ item ])
          .join("rect")
          .attr("class", "visualization-edge-label__background")
          .attr("x", (label) => -(label.width / 2))
          .attr("y", (label) => -(label.height / 2))
          .attr("width", (label) => label.width)
          .attr("height", (label) => label.height)
          .attr("rx", 4)
          .lower()
      })

    const nodeGroup = svg.append("g").attr("class", "visualization-nodes")
    const renderedNodes = nodeGroup.selectAll("g")
      .data(positionedNodes)
      .join("g")
      .attr("transform", (node) => `translate(${node.x},${node.y})`)

    renderedNodes.append("title").text((node) => node.full_name)

    renderedNodes.append("circle")
      .attr("data-user-id", (node) => node.user_id)
      .attr("r", 30)
      .attr("class", "visualization-node")

    renderedNodes.append("text")
      .attr("class", "visualization-node-label")
      .attr("text-anchor", "middle")
      .attr("dy", 48)
      .text((node) => node.short_label)
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
      startX,
      startY,
      controlX,
      controlY,
      endX,
      endY
    }
  }

  placeEdgeLabels(edgeGeometry) {
    const occupied = []
    const candidates = [
      [ 0.35, 0 ], [ 0.65, 0 ],
      ...[ 18, -18, 36, -36, 54, -54, 72, -72, 96, -96 ].flatMap((offset) =>
        [ 0.2, 0.35, 0.5, 0.65, 0.8 ].map((progress) => [ progress, offset ])
      )
    ]
    const labelsByEdge = new Map()

    edgeGeometry
      .toSorted((left, right) => left.edge.from_user_id.localeCompare(right.edge.from_user_id) || left.edge.to_user_id.localeCompare(right.edge.to_user_id))
      .forEach((geometry) => {
        const positions = candidates.map(([progress, offset]) => ({
          ...this.labelPosition(geometry, progress, offset),
          width: geometry.width,
          height: geometry.height
        }))
        const position = positions.find((candidate) => !occupied.some((other) => this.labelsOverlap(candidate, other))) || positions.at(-1)
        const label = { ...geometry, ...position }
        occupied.push(label)
        labelsByEdge.set(`${geometry.edge.from_user_id}:${geometry.edge.to_user_id}`, label)
      })

    return edgeGeometry.map((geometry) => labelsByEdge.get(`${geometry.edge.from_user_id}:${geometry.edge.to_user_id}`))
  }

  labelPosition(geometry, progress, offset) {
    const inverse = 1 - progress
    const anchorX = (inverse ** 2 * geometry.startX) + (2 * inverse * progress * geometry.controlX) + (progress ** 2 * geometry.endX)
    const anchorY = (inverse ** 2 * geometry.startY) + (2 * inverse * progress * geometry.controlY) + (progress ** 2 * geometry.endY)
    const tangentX = (2 * inverse * (geometry.controlX - geometry.startX)) + (2 * progress * (geometry.endX - geometry.controlX))
    const tangentY = (2 * inverse * (geometry.controlY - geometry.startY)) + (2 * progress * (geometry.endY - geometry.controlY))
    const length = Math.hypot(tangentX, tangentY) || 1
    const normalX = -tangentY / length
    const normalY = tangentX / length

    return {
      anchorX,
      anchorY,
      labelX: anchorX + (normalX * offset),
      labelY: anchorY + (normalY * offset),
      offset
    }
  }

  labelsOverlap(left, right) {
    const gap = 8
    return Math.abs(left.labelX - right.labelX) < ((left.width + right.width) / 2) + gap &&
      Math.abs(left.labelY - right.labelY) < ((left.height + right.height) / 2) + gap
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

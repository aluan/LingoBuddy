import SwiftUI

struct KnowledgeGraphView: View {
    let nodes: [KnowledgeNode]
    let onNodeTap: (KnowledgeNode) -> Void

    @State private var nodePositions: [String: CGPoint] = [:]
    @State private var nodeVelocities: [String: CGVector] = [:]
    @State private var selectedNodeId: String?
    @State private var baseOffset: CGSize = .zero
    @State private var baseScale: CGFloat = 1
    @State private var simulationHeat: CGFloat = 1
    @State private var isPhysicsEnabled = true
    @GestureState private var panDelta: CGSize = .zero
    @GestureState private var pinchDelta: CGFloat = 1

    private let simulationTimer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()
    private let minimumScale: CGFloat = 0.62
    private let maximumScale: CGFloat = 2.2

    var body: some View {
        GeometryReader { geometry in
            let viewportSize = geometry.size
            let graphSize = graphCanvasSize(for: viewportSize)
            let connections = nodeConnections
            let degrees = degreeCounts(connections: connections)
            let effectiveScale = clampedScale(baseScale * pinchDelta)
            let effectiveOffset = CGSize(
                width: baseOffset.width + panDelta.width,
                height: baseOffset.height + panDelta.height
            )

            ZStack(alignment: .topLeading) {
                graphBackground

                ZStack(alignment: .topLeading) {
                    edgeLayer(connections: connections, degrees: degrees)

                    ForEach(nodes) { node in
                        if let position = nodePositions[node.id] {
                            ForceGraphNodeView(
                                node: node,
                                radius: nodeRadius(for: node, degrees: degrees),
                                isSelected: selectedNodeId == node.id,
                                isDimmed: shouldDim(nodeId: node.id, connections: connections),
                                degree: degrees[node.id, default: 0]
                            )
                            .position(position)
                            .onTapGesture {
                                selectedNodeId = node.id
                                onNodeTap(node)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(node.displayType), \(node.title)")
                        }
                    }
                }
                .frame(width: graphSize.width, height: graphSize.height)
                .scaleEffect(effectiveScale, anchor: .topLeading)
                .offset(effectiveOffset)
            }
            .frame(width: viewportSize.width, height: viewportSize.height)
            .contentShape(Rectangle())
            .clipped()
            .overlay(alignment: .topTrailing) {
                graphControls(viewportSize: viewportSize, graphSize: graphSize)
            }
            .gesture(panGesture)
            .simultaneousGesture(zoomGesture)
            .onAppear {
                initializeSimulationIfNeeded(viewportSize: viewportSize, graphSize: graphSize)
            }
            .onReceive(simulationTimer) { _ in
                runPhysicsTick(graphSize: graphSize, connections: connections, degrees: degrees)
            }
            .onChange(of: nodes.map(\.id)) { _ in
                selectedNodeId = nil
                resetSimulation(viewportSize: viewportSize, graphSize: graphSize)
            }
            .onChange(of: viewportSize) { _ in
                resetSimulation(viewportSize: viewportSize, graphSize: graphSize)
            }
        }
    }

    private var graphBackground: some View {
        ZStack {
            Color.white.opacity(0.94)
            LinearGradient(
                colors: [
                    Color.white.opacity(0.96),
                    Color(red: 0.95, green: 0.97, blue: 0.98).opacity(0.7)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            GraphPaperTexture()
                .opacity(0.32)
        }
    }

    private func edgeLayer(connections: [GraphConnection], degrees: [String: Int]) -> some View {
        Canvas { context, _ in
            for connection in connections {
                guard let from = nodePositions[connection.from], let to = nodePositions[connection.to] else { continue }

                var path = Path()
                path.move(to: from)
                path.addLine(to: to)

                let highlighted = selectedNodeId == nil || connection.from == selectedNodeId || connection.to == selectedNodeId
                let averageDegree = CGFloat(degrees[connection.from, default: 1] + degrees[connection.to, default: 1]) / 2
                let opacity = highlighted ? min(0.12 + averageDegree * 0.012, 0.34) : 0.045
                let lineWidth = highlighted ? min(0.55 + connection.weight * 0.18, 1.45) : 0.42

                context.stroke(
                    path,
                    with: .color(Color(red: 0.33, green: 0.35, blue: 0.36).opacity(opacity)),
                    lineWidth: lineWidth
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func graphControls(viewportSize: CGSize, graphSize: CGSize) -> some View {
        HStack(spacing: 8) {
            Button {
                isPhysicsEnabled.toggle()
                if isPhysicsEnabled {
                    simulationHeat = max(simulationHeat, 0.35)
                }
            } label: {
                Image(systemName: isPhysicsEnabled ? "pause.fill" : "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 34, height: 34)
            }
            .accessibilityLabel(isPhysicsEnabled ? "Pause graph physics" : "Resume graph physics")

            Button {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                    selectedNodeId = nil
                    baseScale = 1
                    resetSimulation(viewportSize: viewportSize, graphSize: graphSize)
                }
            } label: {
                Image(systemName: "scope")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 34, height: 34)
            }
            .accessibilityLabel("Reflow and center graph")
        }
        .buttonStyle(.plain)
        .background(
            Capsule(style: .continuous)
                .fill(.white.opacity(0.88))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
        .padding(12)
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .updating($panDelta) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                baseOffset.width += value.translation.width
                baseOffset.height += value.translation.height
            }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .updating($pinchDelta) { value, state, _ in
                state = value
            }
            .onEnded { value in
                baseScale = clampedScale(baseScale * value)
            }
    }

    private var nodeConnections: [GraphConnection] {
        guard nodes.count > 1 else { return [] }

        var byPair: [String: GraphConnection] = [:]

        func addConnection(_ a: KnowledgeNode, _ b: KnowledgeNode, weight: CGFloat) {
            guard a.id != b.id else { return }
            let ids = [a.id, b.id].sorted()
            let key = "\(ids[0])::\(ids[1])"
            if let existing = byPair[key] {
                byPair[key] = GraphConnection(from: existing.from, to: existing.to, weight: existing.weight + weight)
            } else {
                byPair[key] = GraphConnection(from: ids[0], to: ids[1], weight: weight)
            }
        }

        for i in 0..<nodes.count {
            for j in (i + 1)..<nodes.count {
                let first = nodes[i]
                let second = nodes[j]
                let sharedTags = Set(first.tags.map { $0.lowercased() }).intersection(Set(second.tags.map { $0.lowercased() }))

                if !sharedTags.isEmpty {
                    addConnection(first, second, weight: 1 + CGFloat(min(sharedTags.count, 3)) * 0.35)
                }

                if let firstVideo = first.sourceVideoId,
                   let secondVideo = second.sourceVideoId,
                   firstVideo == secondVideo {
                    addConnection(first, second, weight: 1.4)
                }

                if first.type == second.type, !sharedTags.isEmpty {
                    addConnection(first, second, weight: 0.35)
                }
            }
        }

        return byPair.values.sorted { lhs, rhs in
            if lhs.from == rhs.from { return lhs.to < rhs.to }
            return lhs.from < rhs.from
        }
    }

    private func shouldDim(nodeId: String, connections: [GraphConnection]) -> Bool {
        guard let selectedNodeId, selectedNodeId != nodeId else { return false }
        return !connections.contains { ($0.from == selectedNodeId && $0.to == nodeId) || ($0.to == selectedNodeId && $0.from == nodeId) }
    }

    private func graphCanvasSize(for viewportSize: CGSize) -> CGSize {
        CGSize(
            width: max(viewportSize.width * 1.9, 760),
            height: max(viewportSize.height * 1.45, 620)
        )
    }

    private func initializeSimulationIfNeeded(viewportSize: CGSize, graphSize: CGSize) {
        guard nodePositions.isEmpty, viewportSize.width > 0, viewportSize.height > 0 else { return }
        resetSimulation(viewportSize: viewportSize, graphSize: graphSize)
    }

    private func resetSimulation(viewportSize: CGSize, graphSize: CGSize) {
        guard viewportSize.width > 0, viewportSize.height > 0 else { return }
        let connections = nodeConnections
        let degrees = degreeCounts(connections: connections)
        let radii = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, nodeRadius(for: $0, degrees: degrees)) })
        let state = ForceGraphPhysics.makeInitialState(
            nodes: nodes,
            connections: connections,
            radii: radii,
            size: graphSize
        )
        nodePositions = state.positions
        nodeVelocities = state.velocities
        simulationHeat = state.heat
        isPhysicsEnabled = true
        centerGraph(viewportSize: viewportSize, graphSize: graphSize)
    }

    private func runPhysicsTick(graphSize: CGSize, connections: [GraphConnection], degrees: [String: Int]) {
        guard isPhysicsEnabled, !nodePositions.isEmpty, nodes.count > 1 else { return }
        let radii = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, nodeRadius(for: $0, degrees: degrees)) })
        let state = ForceGraphPhysics.step(
            nodes: nodes,
            connections: connections,
            positions: nodePositions,
            velocities: nodeVelocities,
            radii: radii,
            size: graphSize,
            heat: simulationHeat
        )
        nodePositions = state.positions
        nodeVelocities = state.velocities
        simulationHeat = state.heat

        if state.heat < 0.035, state.maxVelocity < 0.045 {
            isPhysicsEnabled = false
        }
    }

    private func centerGraph(viewportSize: CGSize, graphSize: CGSize) {
        baseOffset = CGSize(
            width: (viewportSize.width - graphSize.width) / 2,
            height: (viewportSize.height - graphSize.height) / 2
        )
    }

    private func clampedScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, minimumScale), maximumScale)
    }

    private func degreeCounts(connections: [GraphConnection]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for connection in connections {
            counts[connection.from, default: 0] += 1
            counts[connection.to, default: 0] += 1
        }
        return counts
    }

    private func nodeRadius(for node: KnowledgeNode, degrees: [String: Int]) -> CGFloat {
        let degree = CGFloat(degrees[node.id, default: 0])
        let base: CGFloat
        switch node.type {
        case "video_note": base = 9.5
        case "quiz_mistake": base = 8.5
        default: base = 7.2
        }
        return min(base + sqrt(degree) * 2.25, 22)
    }
}

private struct GraphConnection: Identifiable, Hashable {
    let from: String
    let to: String
    let weight: CGFloat

    var id: String { "\(from)::\(to)" }
}

private struct ForceGraphNodeView: View {
    let node: KnowledgeNode
    let radius: CGFloat
    let isSelected: Bool
    let isDimmed: Bool
    let degree: Int

    var body: some View {
        VStack(spacing: 3) {
            Circle()
                .fill(nodeFill)
                .frame(width: radius * 2, height: radius * 2)
                .overlay {
                    Circle()
                        .stroke(.white.opacity(isSelected ? 0.95 : 0.55), lineWidth: isSelected ? 2.2 : 0.7)
                }
                .shadow(color: .black.opacity(isSelected ? 0.24 : 0.06), radius: isSelected ? 9 : 2, x: 0, y: isSelected ? 5 : 1)
                .scaleEffect(isSelected ? 1.16 : 1)

            Text(node.title)
                .font(.system(size: labelSize, weight: isSelected ? .semibold : .regular, design: .default))
                .foregroundStyle(Color(red: 0.12, green: 0.13, blue: 0.14).opacity(isDimmed ? 0.25 : 0.84))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: min(max(CGFloat(node.title.count) * 7.2, 68), 168))
                .padding(.horizontal, isSelected ? 5 : 0)
                .padding(.vertical, isSelected ? 3 : 0)
                .background {
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                    }
                }
        }
        .opacity(isDimmed ? 0.42 : 1)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isSelected)
        .animation(.easeInOut(duration: 0.18), value: isDimmed)
    }

    private var labelSize: CGFloat {
        if isSelected { return 14 }
        if degree >= 8 { return 13 }
        return 12
    }

    private var nodeFill: Color {
        if isDimmed { return Color(red: 0.74, green: 0.75, blue: 0.75) }
        if isSelected { return Color(red: 0.1, green: 0.1, blue: 0.1) }
        switch node.type {
        case "video_note": return Color(red: 0.29, green: 0.30, blue: 0.31)
        case "vocabulary": return Color(red: 0.35, green: 0.36, blue: 0.37)
        case "sentence": return Color(red: 0.39, green: 0.40, blue: 0.41)
        case "quiz_mistake": return Color(red: 0.24, green: 0.25, blue: 0.26)
        case "question": return Color(red: 0.58, green: 0.59, blue: 0.60)
        default: return Color(red: 0.42, green: 0.43, blue: 0.44)
        }
    }
}

private struct GraphPaperTexture: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 34
            var path = Path()

            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }

            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }

            context.stroke(path, with: .color(Color.black.opacity(0.022)), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }
}

private struct ForceGraphState {
    var positions: [String: CGPoint]
    var velocities: [String: CGVector]
    var heat: CGFloat
    var maxVelocity: CGFloat
}

private enum ForceGraphPhysics {
    private static let damping: CGFloat = 0.82
    private static let repulsionStrength: CGFloat = 260_000
    private static let springStrength: CGFloat = 0.018
    private static let centerGravity: CGFloat = 0.0048
    private static let boundaryStrength: CGFloat = 0.09
    private static let collisionStrength: CGFloat = 0.42
    private static let collisionPadding: CGFloat = 34
    private static let velocityScale: CGFloat = 0.035
    private static let maxVelocity: CGFloat = 18
    private static let margin: CGFloat = 58

    static func makeInitialState(
        nodes: [KnowledgeNode],
        connections: [GraphConnection],
        radii: [String: CGFloat],
        size: CGSize
    ) -> ForceGraphState {
        var positions = seededInitialPositions(nodes: nodes, size: size, margin: margin)
        var velocities = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, CGVector(dx: 0, dy: 0)) })
        var heat: CGFloat = 1
        var maxVelocity: CGFloat = 0

        // A short invisible warm-up avoids the unreadable first-frame knot while still
        // leaving enough heat for users to see the graph breathe into equilibrium.
        for _ in 0..<70 {
            let state = step(
                nodes: nodes,
                connections: connections,
                positions: positions,
                velocities: velocities,
                radii: radii,
                size: size,
                heat: heat,
                cooling: 0.988
            )
            positions = state.positions
            velocities = state.velocities
            heat = state.heat
            maxVelocity = state.maxVelocity
        }

        return ForceGraphState(
            positions: positions,
            velocities: velocities,
            heat: max(heat, 0.62),
            maxVelocity: maxVelocity
        )
    }

    static func step(
        nodes: [KnowledgeNode],
        connections: [GraphConnection],
        positions: [String: CGPoint],
        velocities: [String: CGVector],
        radii: [String: CGFloat],
        size: CGSize,
        heat: CGFloat,
        cooling: CGFloat = 0.982
    ) -> ForceGraphState {
        guard !nodes.isEmpty else {
            return ForceGraphState(positions: [:], velocities: [:], heat: 0, maxVelocity: 0)
        }

        let ids = nodes.map(\.id)
        var nextPositions = positions
        var nextVelocities = velocities
        var forces = Dictionary(uniqueKeysWithValues: ids.map { ($0, CGVector(dx: 0, dy: 0)) })
        let safeWidth = max(size.width, 1)
        let safeHeight = max(size.height, 1)
        let area = safeWidth * safeHeight
        let idealDistance = max(82, sqrt(area / CGFloat(max(nodes.count, 1))) * 0.72)
        let center = CGPoint(x: safeWidth / 2, y: safeHeight / 2)
        let effectiveHeat = max(heat, 0.08)

        // Coulomb-style repulsion + collision separation.
        for i in nodes.indices {
            for j in nodes.indices where j > i {
                let left = nodes[i].id
                let right = nodes[j].id
                guard let leftPosition = positions[left], let rightPosition = positions[right] else { continue }

                var delta = leftPosition - rightPosition
                var distance = delta.length
                if distance < 0.1 {
                    let seed = CGFloat((stableHash(left + right) % 628) + 1) / 100
                    delta = CGVector(dx: cos(seed), dy: sin(seed))
                    distance = 1
                }

                let direction = delta / distance
                let leftRadius = radii[left, default: 8]
                let rightRadius = radii[right, default: 8]
                let minimumDistance = leftRadius + rightRadius + collisionPadding
                let repulsion = min(repulsionStrength / max(distance * distance, 100), 34)
                let collision = distance < minimumDistance ? (minimumDistance - distance) * collisionStrength : 0
                let force = direction * (repulsion + collision)

                forces[left, default: .zero] = forces[left, default: .zero] + force
                forces[right, default: .zero] = forces[right, default: .zero] - force
            }
        }

        // Hooke spring attraction for graph links. Stronger semantic links pull tighter.
        for connection in connections {
            guard let fromPosition = positions[connection.from], let toPosition = positions[connection.to] else { continue }
            let delta = toPosition - fromPosition
            let distance = max(delta.length, 1)
            let direction = delta / distance
            let desiredDistance = idealDistance / min(max(connection.weight, 0.75), 2.35)
            let displacement = distance - desiredDistance
            let force = direction * (displacement * springStrength * min(connection.weight, 3.4))

            forces[connection.from, default: .zero] = forces[connection.from, default: .zero] + force
            forces[connection.to, default: .zero] = forces[connection.to, default: .zero] - force
        }

        var measuredMaxVelocity: CGFloat = 0

        for node in nodes {
            let id = node.id
            guard let position = positions[id] else { continue }

            var force = forces[id, default: .zero]
            let toCenter = center - position
            force = force + CGVector(dx: toCenter.dx * centerGravity, dy: toCenter.dy * centerGravity)

            if position.x < margin {
                force.dx += (margin - position.x) * boundaryStrength
            } else if position.x > safeWidth - margin {
                force.dx -= (position.x - (safeWidth - margin)) * boundaryStrength
            }

            if position.y < margin {
                force.dy += (margin - position.y) * boundaryStrength
            } else if position.y > safeHeight - margin {
                force.dy -= (position.y - (safeHeight - margin)) * boundaryStrength
            }

            let previousVelocity = velocities[id, default: .zero]
            let velocityLimit = max(2.4, maxVelocity * effectiveHeat)
            let velocity = ((previousVelocity + force * velocityScale * effectiveHeat) * damping).limited(to: velocityLimit)
            measuredMaxVelocity = max(measuredMaxVelocity, velocity.length)

            nextVelocities[id] = velocity
            nextPositions[id] = CGPoint(
                x: min(max(position.x + velocity.dx, margin), safeWidth - margin),
                y: min(max(position.y + velocity.dy, margin), safeHeight - margin)
            )
        }

        let cooledHeat = max(0, heat * cooling - 0.0015)
        return ForceGraphState(
            positions: nextPositions,
            velocities: nextVelocities,
            heat: cooledHeat,
            maxVelocity: measuredMaxVelocity
        )
    }

    private static func seededInitialPositions(nodes: [KnowledgeNode], size: CGSize, margin: CGFloat) -> [String: CGPoint] {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let xRadius = max(size.width / 2 - margin, 20)
        let yRadius = max(size.height / 2 - margin, 20)

        return Dictionary(uniqueKeysWithValues: nodes.enumerated().map { index, node in
            let seed = stableHash(node.id)
            let jitterA = CGFloat(seed % 1_000) / 1_000
            let jitterB = CGFloat((seed / 1_000) % 1_000) / 1_000
            let angle = (CGFloat(index) / CGFloat(max(nodes.count, 1)) + jitterA * 0.18) * .pi * 2
            let radius = 0.2 + 0.74 * jitterB
            return (
                node.id,
                CGPoint(
                    x: center.x + cos(angle) * xRadius * radius,
                    y: center.y + sin(angle) * yRadius * radius
                )
            )
        })
    }

    private static func stableHash(_ value: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }
}

private extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGVector) -> CGPoint {
        CGPoint(x: lhs.x + rhs.dx, y: lhs.y + rhs.dy)
    }

    static func - (lhs: CGPoint, rhs: CGPoint) -> CGVector {
        CGVector(dx: lhs.x - rhs.x, dy: lhs.y - rhs.y)
    }
}

private extension CGVector {
    static func + (lhs: CGVector, rhs: CGVector) -> CGVector {
        CGVector(dx: lhs.dx + rhs.dx, dy: lhs.dy + rhs.dy)
    }

    static func - (lhs: CGVector, rhs: CGVector) -> CGVector {
        CGVector(dx: lhs.dx - rhs.dx, dy: lhs.dy - rhs.dy)
    }

    static func * (lhs: CGVector, rhs: CGFloat) -> CGVector {
        CGVector(dx: lhs.dx * rhs, dy: lhs.dy * rhs)
    }

    static func / (lhs: CGVector, rhs: CGFloat) -> CGVector {
        CGVector(dx: lhs.dx / rhs, dy: lhs.dy / rhs)
    }

    var length: CGFloat {
        sqrt(dx * dx + dy * dy)
    }

    func limited(to maximum: CGFloat) -> CGVector {
        let currentLength = length
        guard currentLength > maximum, currentLength > 0 else { return self }
        return self / currentLength * maximum
    }
}

#Preview {
    KnowledgeGraphView(
        nodes: [
            KnowledgeNode(
                id: "1",
                type: "video_note",
                title: "English Grammar",
                body: "Basic grammar rules",
                key: nil,
                tags: ["grammar", "basics"],
                sourceVideoId: "v1",
                metadata: nil,
                createdAt: nil,
                updatedAt: nil
            ),
            KnowledgeNode(
                id: "2",
                type: "vocabulary",
                title: "Hello",
                body: "A greeting",
                key: nil,
                tags: ["basics", "greetings"],
                sourceVideoId: "v1",
                metadata: nil,
                createdAt: nil,
                updatedAt: nil
            ),
            KnowledgeNode(
                id: "3",
                type: "sentence",
                title: "How are you?",
                body: "Common question",
                key: nil,
                tags: ["greetings", "questions"],
                sourceVideoId: "v2",
                metadata: nil,
                createdAt: nil,
                updatedAt: nil
            ),
            KnowledgeNode(
                id: "4",
                type: "quiz_mistake",
                title: "Present tense mistake",
                body: "Common tense mismatch",
                key: nil,
                tags: ["grammar", "questions"],
                sourceVideoId: "v2",
                metadata: nil,
                createdAt: nil,
                updatedAt: nil
            )
        ],
        onNodeTap: { _ in }
    )
    .frame(height: 420)
    .padding()
}

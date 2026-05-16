import SwiftUI

struct KnowledgeView: View {
    @StateObject private var service = KnowledgeService()
    @State private var searchText = ""
    @State private var searchResults: [KnowledgeNode] = []
    @State private var isSearching = false
    @State private var selectedNode: KnowledgeNode?

    private let pageGradient = LinearGradient(
        colors: [
            Color(red: 0.96, green: 0.99, blue: 0.97),
            Color(red: 0.86, green: 0.94, blue: 1.0)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        NavigationStack {
            ZStack {
                pageGradient.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        searchBar

                        if service.isLoading {
                            ProgressView("Loading knowledge...")
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        } else if let error = service.errorMessage {
                            emptyState(title: "Could not load Knowledge", message: error, icon: "wifi.exclamationmark")
                        } else if isSearching {
                            graphSection(title: "Search Results", nodes: searchResults)
                        } else if let home = service.home {
                            let allNodes = home.recentNodes + home.videoNotes + home.vocabulary + home.mistakes
                            if allNodes.isEmpty {
                                emptyState(
                                    title: "Build your English Knowledge Map",
                                    message: "Open a completed video and tap Knowledge to turn it into words, sentences, mistakes, and links.",
                                    icon: "sparkles.rectangle.stack.fill"
                                )
                            } else {
                                graphSection(title: "Knowledge Graph", nodes: Array(Set(allNodes)))
                                legendSection
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
                .refreshable {
                    await service.fetchHome()
                }
            }
            .navigationBarHidden(true)
            .task {
                await service.fetchHome()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Knowledge")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
            Text("Your English second brain")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search videos, words, mistakes", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { Task { await runSearch() } }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchResults = []
                    isSearching = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.82)))
    }

    private func graphSection(title: String, nodes: [KnowledgeNode]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))

            if nodes.isEmpty {
                Text("Nothing here yet")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.65)))
            } else {
                NavigationLink(
                    destination: Group {
                        if let node = selectedNode {
                            KnowledgeNodeDetailView(nodeId: node.id, initialNode: node)
                        }
                    },
                    isActive: Binding(
                        get: { selectedNode != nil },
                        set: { if !$0 { selectedNode = nil } }
                    )
                ) {
                    EmptyView()
                }
                .hidden()

                KnowledgeGraphView(nodes: nodes) { node in
                    selectedNode = node
                }
                .frame(height: 500)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.82)))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }

    private var legendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Node Types")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                legendItem(title: "Video", icon: "play.rectangle.fill", color: Color(red: 0.13, green: 0.53, blue: 0.45))
                legendItem(title: "Word", icon: "textformat.abc", color: Color(red: 0.12, green: 0.45, blue: 0.78))
                legendItem(title: "Sentence", icon: "quote.bubble.fill", color: Color(red: 0.48, green: 0.33, blue: 0.78))
                legendItem(title: "Mistake", icon: "exclamationmark.triangle.fill", color: Color(red: 0.86, green: 0.38, blue: 0.18))
                legendItem(title: "Question", icon: "questionmark.bubble.fill", color: Color(red: 0.85, green: 0.62, blue: 0.12))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.82)))
    }

    private func legendItem(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(Circle().fill(color.opacity(0.16)))

            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))

            Spacer()
        }
    }

    private func emptyState(title: String, message: String, icon: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(Color(red: 0.13, green: 0.53, blue: 0.45))
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text(message)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.78)))
    }

    private func runSearch() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        do {
            searchResults = try await service.search(query: query)
        } catch {
            searchResults = []
            service.errorMessage = error.localizedDescription
        }
    }
}

struct KnowledgeNodeRow: View {
    let node: KnowledgeNode

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.16))
                Image(systemName: node.iconName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(color)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(node.displayType)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                    if !node.tags.isEmpty {
                        Text(node.tags.prefix(2).joined(separator: " · "))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(node.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                    .lineLimit(2)

                if !node.body.isEmpty {
                    Text(node.body)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.82)))
    }

    private var color: Color {
        switch node.type {
        case "video_note": return Color(red: 0.13, green: 0.53, blue: 0.45)
        case "vocabulary": return Color(red: 0.12, green: 0.45, blue: 0.78)
        case "sentence": return Color(red: 0.48, green: 0.33, blue: 0.78)
        case "quiz_mistake": return Color(red: 0.86, green: 0.38, blue: 0.18)
        case "question": return Color(red: 0.85, green: 0.62, blue: 0.12)
        default: return .secondary
        }
    }
}

struct KnowledgeNodeDetailView: View {
    let nodeId: String
    let initialNode: KnowledgeNode
    @StateObject private var service = KnowledgeService()
    @State private var node: KnowledgeNode
    @State private var links: [KnowledgeLink] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(nodeId: String, initialNode: KnowledgeNode) {
        self.nodeId = nodeId
        self.initialNode = initialNode
        _node = State(initialValue: initialNode)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.99, blue: 0.97), Color(red: 0.88, green: 0.95, blue: 1.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    detailHeader
                    bodyCard
                    metadataCard
                    localGraph
                    relatedList
                }
                .padding(20)
            }
        }
        .navigationTitle(node.displayType)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task(id: nodeId) { await load() }
    }

    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(node.displayType, systemImage: node.iconName)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.13, green: 0.53, blue: 0.45))
            Text(node.title)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
            if !node.tags.isEmpty {
                FlexibleTags(tags: node.tags)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.82)))
    }

    private var bodyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Note")
                .font(.system(size: 17, weight: .bold, design: .rounded))
            Text(node.body.isEmpty ? "No note yet." : node.body)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white.opacity(0.78)))
    }

    private var metadataCard: some View {
        let metadata = node.metadata ?? [:]
        return Group {
            if !metadata.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Details")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    ForEach(metadata.keys.sorted(), id: \.self) { key in
                        HStack(alignment: .top) {
                            Text(key)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                                .frame(width: 110, alignment: .leading)
                            Text(display(metadata[key]))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white.opacity(0.78)))
            }
        }
    }

    private var localGraph: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Local Graph")
                .font(.system(size: 17, weight: .bold, design: .rounded))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    graphNode(node.title, icon: node.iconName, highlighted: true)
                    ForEach(links.prefix(8)) { link in
                        Image(systemName: "arrow.left.and.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                        NavigationLink(value: link.node) {
                            graphNode(link.node.title, icon: link.node.iconName, highlighted: false)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white.opacity(0.78)))
        .navigationDestination(for: KnowledgeNode.self) { node in
            KnowledgeNodeDetailView(nodeId: node.id, initialNode: node)
        }
    }

    private var relatedList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Linked Nodes")
                .font(.system(size: 17, weight: .bold, design: .rounded))
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            } else if links.isEmpty {
                Text("No links yet")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(links) { link in
                    NavigationLink(value: link.node) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(link.relation.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                            KnowledgeNodeRow(node: link.node)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func graphNode(_ title: String, icon: String, highlighted: Bool) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(highlighted ? .white : Color(red: 0.13, green: 0.53, blue: 0.45))
                .frame(width: 48, height: 48)
                .background(Circle().fill(highlighted ? Color(red: 0.13, green: 0.53, blue: 0.45) : .white.opacity(0.9)))
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 86)
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let detail = try await service.fetchNodeDetail(nodeId: nodeId)
            node = detail.node
            links = detail.links
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func display(_ value: JSONValue?) -> String {
        guard let value else { return "" }
        switch value {
        case .string(let text): return text
        case .number(let number): return number.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(number)) : String(number)
        case .bool(let bool): return bool ? "true" : "false"
        case .array(let array): return array.map { display($0) }.joined(separator: ", ")
        case .object(let object): return object.map { "\($0.key): \(display($0.value))" }.joined(separator: ", ")
        case .null: return ""
        }
    }
}

struct FlexibleTags: View {
    let tags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.13, green: 0.53, blue: 0.45))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color(red: 0.13, green: 0.53, blue: 0.45).opacity(0.12)))
                }
            }
        }
    }
}

#Preview {
    KnowledgeView()
}


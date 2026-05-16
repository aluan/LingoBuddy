import SwiftUI

struct VideoDetailView: View {
    let video: VideoContent
    let onBack: () -> Void
    var onDelete: (() -> Void)? = nil

    @State private var showTextChat = false
    @State private var showVoiceChat = false
    @State private var showQuiz = false
    @State private var knowledgeNodes: [KnowledgeNode] = []
    @State private var isBuildingKnowledge = false
    @State private var knowledgeMessage: String?
    @State private var selectedKnowledgeNode: KnowledgeNode?
    @StateObject private var knowledgeService = KnowledgeService()
    @State private var showDeleteConfirmation = false

    private let pageGradient = LinearGradient(
        colors: [
            Color(red: 0.95, green: 0.99, blue: 0.96),
            Color(red: 0.82, green: 0.94, blue: 0.98)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        ZStack {
            pageGradient.ignoresSafeArea()

            navigationLinks

            ScrollView {
                VStack(spacing: 20) {
                    if video.thumbnailUrl != nil {
                        thumbnailHero
                    }

                    videoInfoCard

                    summarySection

                    knowledgeSection

                    actionButtons
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Video Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if onDelete != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive, action: {
                            showDeleteConfirmation = true
                        }) {
                            Label("Delete Video", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .confirmationDialog("Delete this video?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                onDelete?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .task {
            await loadVideoKnowledge()
        }
    }

    private var navigationLinks: some View {
        Group {
            NavigationLink(
                destination: VideoTextChatView(
                    videoId: video.id,
                    videoContext: video.transcriptText ?? "",
                    onBack: { showTextChat = false }
                )
                .navigationBarBackButtonHidden(true),
                isActive: $showTextChat
            ) {
                EmptyView()
            }
            .hidden()

            NavigationLink(
                destination: VideoVoiceChatView(
                    videoId: video.id,
                    videoTitle: video.title,
                    videoContext: video.transcriptText ?? "",
                    onBack: { showVoiceChat = false }
                )
                .navigationBarBackButtonHidden(true),
                isActive: $showVoiceChat
            ) {
                EmptyView()
            }
            .hidden()

            NavigationLink(
                destination: VideoQuizView(
                    videoId: video.id,
                    onBack: { showQuiz = false }
                )
                .navigationBarBackButtonHidden(true),
                isActive: $showQuiz
            ) {
                EmptyView()
            }
            .hidden()

            NavigationLink(
                destination: Group {
                    if let node = selectedKnowledgeNode {
                        KnowledgeNodeDetailView(nodeId: node.id, initialNode: node)
                    }
                },
                isActive: Binding(
                    get: { selectedKnowledgeNode != nil },
                    set: { if !$0 { selectedKnowledgeNode = nil } }
                )
            ) {
                EmptyView()
            }
            .hidden()
        }
    }

    private var thumbnailHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            AsyncImage(url: URL(string: video.thumbnailUrl ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure, .empty:
                    Rectangle()
                        .fill(.secondary.opacity(0.15))
                        .overlay(
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                        )
                @unknown default:
                    EmptyView()
                }
            }
            .aspectRatio(16/9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 8) {
                    Text(formatDuration(video.duration))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))

                    if let source = video.transcriptSource {
                        Text("•")
                        Text(source.uppercased())
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(
                        colors: [.black.opacity(0.6), .black.opacity(0.3)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                )
                .padding(12)
            }

            Text(video.title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                .lineLimit(2)
        }
    }

    private var videoInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if video.thumbnailUrl == nil {
                Text(video.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
            }

            HStack(spacing: 16) {
                Label(formatDuration(video.duration), systemImage: "clock")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                if let source = video.transcriptSource {
                    Label(source.capitalized, systemImage: source == "subtitle" ? "captions.bubble" : "waveform")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.78))
        )
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "text.quote")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(red: 0.13, green: 0.53, blue: 0.45))
                Text("Summary")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
            }

            if let summary = videoSummaryText {
                Text(summary)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .lineSpacing(5)
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let source = video.transcriptSource {
                    Label("Generated from \(source.capitalized)", systemImage: "sparkles")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(video.transcriptStatus == "completed" ? "No summary available yet." : "Summary will be available after the transcript is ready.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.78))
        )
    }

    private var videoSummaryText: String? {
        guard let transcript = video.transcriptText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !transcript.isEmpty else { return nil }
        return Self.makeSummary(from: transcript)
    }

    private static func makeSummary(from transcript: String) -> String {
        let normalized = transcript
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalized.count > 760 else { return normalized }

        let rawSentences = normalized
            .components(separatedBy: CharacterSet(charactersIn: "。！？.!?\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 12 }

        guard !rawSentences.isEmpty else {
            return String(normalized.prefix(720)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
        }

        let stopWords: Set<String> = [
            "the", "and", "that", "this", "with", "from", "have", "will", "your", "you", "are", "for", "but", "not", "was", "were", "they", "their", "what", "when", "where", "who", "how", "why", "can", "about", "into", "just", "like", "because", "所以", "然后", "这个", "那个", "我们", "你们", "他们", "就是", "一个", "一些"
        ]

        var frequencies: [String: Int] = [:]
        for token in normalized.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter({ $0.count > 2 && !stopWords.contains($0) }) {
            frequencies[token, default: 0] += 1
        }

        let scored = rawSentences.enumerated().map { index, sentence -> (index: Int, sentence: String, score: Double) in
            let tokens = sentence.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 2 && !stopWords.contains($0) }
            let keywordScore = tokens.reduce(0) { $0 + frequencies[$1, default: 0] }
            let positionBoost = index < 3 ? 3 : max(0, 2 - index / 6)
            let lengthPenalty = sentence.count > 180 ? -2 : 0
            return (index, sentence, Double(keywordScore + positionBoost + lengthPenalty))
        }

        let selected = scored
            .sorted { lhs, rhs in
                if lhs.score == rhs.score { return lhs.index < rhs.index }
                return lhs.score > rhs.score
            }
            .sorted { $0.index < $1.index }
            .map(\.sentence)

        var summary = ""
        for sentence in selected {
            let candidate = summary.isEmpty ? sentence : "\(summary)。\(sentence)"
            if candidate.count > 760 { break }
            summary = candidate
        }

        if summary.isEmpty {
            summary = String(normalized.prefix(720)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if !summary.hasSuffix("。"), !summary.hasSuffix(".") {
            summary += normalized.contains("。") || normalized.contains("，") ? "。" : "."
        }
        return summary
    }

    private var knowledgeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Knowledge Map")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))

                Spacer()

                Button {
                    Task { await buildKnowledge() }
                } label: {
                    HStack(spacing: 6) {
                        if isBuildingKnowledge {
                            ProgressView()
                                .scaleEffect(0.78)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isBuildingKnowledge ? "Building" : "Build")
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.13, green: 0.53, blue: 0.45))
                }
                .buttonStyle(.plain)
                .disabled(isBuildingKnowledge || video.transcriptStatus != "completed")
            }

            if let knowledgeMessage {
                Text(knowledgeMessage)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if knowledgeNodes.isEmpty {
                Text(video.transcriptStatus == "completed" ? "Build this video into vocabulary, sentences, questions, and mistakes." : "Knowledge can be built after transcript is ready.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 10) {
                    ForEach(knowledgeNodes.prefix(8)) { node in
                        Button {
                            selectedKnowledgeNode = node
                        } label: {
                            KnowledgeNodeRow(node: node)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.78))
        )
    }

    private func buildKnowledge() async {
        guard video.transcriptStatus == "completed" else {
            knowledgeMessage = "Transcript is not ready yet."
            return
        }
        isBuildingKnowledge = true
        knowledgeMessage = nil
        do {
            let response = try await knowledgeService.buildVideoKnowledge(videoId: video.id)
            knowledgeNodes = response.nodes
            knowledgeMessage = "Built \(response.created.vocabulary) words, \(response.created.sentences) sentences, \(response.created.questions) questions, and \(response.created.mistakes) mistakes."
        } catch {
            knowledgeMessage = error.localizedDescription
        }
        isBuildingKnowledge = false
    }

    private func loadVideoKnowledge() async {
        do {
            knowledgeNodes = try await knowledgeService.fetchVideoKnowledge(videoId: video.id)
        } catch {
            // Keep this quiet; the user can still build knowledge manually.
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            CompactActionButton(
                title: "Chat",
                icon: "message.fill",
                color: Color(red: 0.13, green: 0.53, blue: 0.45),
                action: { showTextChat = true }
            )

            CompactActionButton(
                title: "Voice",
                icon: "phone.fill",
                color: Color(red: 0.12, green: 0.45, blue: 0.78),
                action: { showVoiceChat = true }
            )

            CompactActionButton(
                title: "Quiz",
                icon: "checkmark.circle.fill",
                color: Color(red: 0.86, green: 0.38, blue: 0.18),
                action: { showQuiz = true }
            )

            CompactActionButton(
                title: "Knowledge",
                icon: "circle.hexagongrid.fill",
                color: Color(red: 0.48, green: 0.33, blue: 0.78),
                action: { Task { await buildKnowledge() } }
            )
        }
    }

    private var statsSection: some View {
        HStack(spacing: 12) {
            StatCard(
                value: "\(video.conversationCount)",
                label: "Conversations",
                icon: "bubble.left.and.bubble.right.fill",
                action: { showTextChat = true }
            )

            StatCard(
                value: "\(video.quizCount)",
                label: "Quizzes",
                icon: "list.bullet.clipboard.fill",
                action: { showQuiz = true }
            )
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct CompactActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(color)

                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.78))
            )
        }
        .buttonStyle(.plain)
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))

                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(color)
            )
        }
        .buttonStyle(.plain)
    }
}

struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: {
            action?()
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(Color(red: 0.13, green: 0.53, blue: 0.45))

                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))

                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.78))
            )
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

#Preview {
    VideoDetailView(
        video: VideoContent(
            id: "1",
            url: "https://bilibili.com",
            videoId: "BV123",
            title: "Sample Video",
            duration: 300,
            thumbnailUrl: nil,
            contentType: "video",
            platform: "bilibili",
            transcriptStatus: "completed",
            transcriptSource: "subtitle",
            transcriptText: "This is a sample transcript...",
            conversationCount: 5,
            quizCount: 2,
            createdAt: Date()
        ),
        onBack: {}
    )
}

import SwiftUI

struct VideoDetailView: View {
    let video: VideoContent
    let onBack: () -> Void
    var onDelete: (() -> Void)? = nil

    @State private var showTextChat = false
    @State private var showVoiceChat = false
    @State private var showQuiz = false
    @State private var isTranscriptExpanded = false
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

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        topBar

                        if video.thumbnailUrl != nil {
                            thumbnailHero
                        }

                        videoInfoCard

                        transcriptSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }

                actionButtons
                    .padding(.horizontal, 20)
                    .padding(.bottom, 26)
            }
        }
        .sheet(isPresented: $showTextChat) {
            VideoTextChatView(
                videoId: video.id,
                videoContext: video.transcriptText ?? "",
                onBack: { showTextChat = false }
            )
        }
        .sheet(isPresented: $showVoiceChat) {
            VideoVoiceChatView(
                videoId: video.id,
                videoTitle: video.title,
                videoContext: video.transcriptText ?? "",
                onBack: { showVoiceChat = false }
            )
        }
        .sheet(isPresented: $showQuiz) {
            VideoQuizView(
                videoId: video.id,
                onBack: { showQuiz = false }
            )
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(.white.opacity(0.78)))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text("Video Details")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
            }

            Spacer()

            if onDelete != nil {
                Menu {
                    Button(role: .destructive, action: {
                        showDeleteConfirmation = true
                    }) {
                        Label("Delete Video", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(.white.opacity(0.78)))
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

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transcript")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))

            if let transcript = video.transcriptText, !transcript.isEmpty {
                Text(transcript)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                    .lineLimit(isTranscriptExpanded ? nil : 8)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isTranscriptExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text(isTranscriptExpanded ? "Show less" : "Show more")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Image(systemName: isTranscriptExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(Color(red: 0.13, green: 0.53, blue: 0.45))
                }
                .buttonStyle(.plain)
            } else {
                Text("No transcript available")
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

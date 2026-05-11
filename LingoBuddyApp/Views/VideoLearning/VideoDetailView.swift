import SwiftUI

struct VideoDetailView: View {
    let video: VideoContent
    let onBack: () -> Void

    @State private var showTextChat = false
    @State private var showVoiceChat = false
    @State private var showQuiz = false

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

            ScrollView {
                VStack(spacing: 20) {
                    topBar

                    videoInfoCard

                    transcriptSection

                    actionButtons

                    statsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 26)
            }
        }
        .sheet(isPresented: $showTextChat) {
            // VideoTextChatView(videoId: video.id, videoContext: video.transcriptText ?? "")
        }
        .sheet(isPresented: $showVoiceChat) {
            // VideoVoiceChatView(videoId: video.id, videoContext: video.transcriptText ?? "", onBack: { showVoiceChat = false })
        }
        .sheet(isPresented: $showQuiz) {
            // VideoQuizView(videoId: video.id)
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
        }
    }

    private var videoInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(video.title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))

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

            ScrollView {
                Text(video.transcriptText ?? "No transcript available")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.78))
        )
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            ActionButton(
                title: "Text Chat",
                icon: "message.fill",
                color: Color(red: 0.13, green: 0.53, blue: 0.45),
                action: { showTextChat = true }
            )

            ActionButton(
                title: "Voice Call",
                icon: "phone.fill",
                color: Color(red: 0.12, green: 0.45, blue: 0.78),
                action: { showVoiceChat = true }
            )

            ActionButton(
                title: "Take Quiz",
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
                icon: "bubble.left.and.bubble.right.fill"
            )

            StatCard(
                value: "\(video.quizCount)",
                label: "Quizzes",
                icon: "list.bullet.clipboard.fill"
            )
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
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

    var body: some View {
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

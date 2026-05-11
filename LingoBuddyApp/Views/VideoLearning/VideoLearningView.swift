import SwiftUI

struct VideoLearningView: View {
    let onBack: () -> Void
    @StateObject private var viewModel = VideoLearningViewModel()
    @State private var urlInput = ""
    @State private var showProcessing = false
    @State private var processingVideoId: String?

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

            VStack(spacing: 20) {
                topBar

                urlInputSection

                if viewModel.isLoading {
                    ProgressView("Loading videos...")
                } else if viewModel.videos.isEmpty {
                    emptyState
                } else {
                    videoList
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .onAppear {
            Task {
                await viewModel.loadVideos()
            }
        }
        .sheet(isPresented: $showProcessing) {
            if let videoId = processingVideoId {
                VideoProcessingView(videoId: videoId, onComplete: { video in
                    showProcessing = false
                    processingVideoId = nil
                    Task {
                        await viewModel.loadVideos()
                    }
                })
            }
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
                Text("Video Learning")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                Text("Learn from videos")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var urlInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bilibili Video URL")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))

            HStack(spacing: 12) {
                TextField("https://www.bilibili.com/video/BV...", text: $urlInput)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.white.opacity(0.78))
                    )

                Button(action: submitVideo) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color(red: 0.13, green: 0.53, blue: 0.45))
                }
                .buttonStyle(.plain)
                .disabled(urlInput.isEmpty || viewModel.isSubmitting)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.70))
        )
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(Color(red: 0.13, green: 0.53, blue: 0.45).opacity(0.5))

            Text("No videos yet")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))

            Text("Add a Bilibili video URL to start learning")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private var videoList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(viewModel.videos) { video in
                    VideoCard(video: video, onTap: {
                        // Navigate to detail
                    })
                }
            }
        }
    }

    private func submitVideo() {
        Task {
            do {
                let videoId = try await viewModel.submitVideo(url: urlInput)
                urlInput = ""
                processingVideoId = videoId
                showProcessing = true
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }
}

struct VideoCard: View {
    let video: VideoContent
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text(formatDuration(video.duration))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)

                        if let source = video.transcriptSource {
                            Text("• \(source)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(statusText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(statusColor)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.78))
            )
        }
        .buttonStyle(.plain)
    }

    private var statusColor: Color {
        switch video.transcriptStatus {
        case "completed":
            return Color(red: 0.13, green: 0.53, blue: 0.45)
        case "processing":
            return Color(red: 0.86, green: 0.52, blue: 0.14)
        case "failed":
            return .red
        default:
            return .gray
        }
    }

    private var statusText: String {
        switch video.transcriptStatus {
        case "completed":
            return "Ready"
        case "processing":
            return "Processing..."
        case "failed":
            return "Failed"
        default:
            return "Pending"
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

@MainActor
final class VideoLearningViewModel: ObservableObject {
    @Published var videos: [VideoContent] = []
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    private let service = VideoLearningService()

    func loadVideos() async {
        isLoading = true
        errorMessage = nil

        do {
            videos = try await service.fetchVideoList()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func submitVideo(url: String) async throws -> String {
        isSubmitting = true
        errorMessage = nil

        defer { isSubmitting = false }

        return try await service.submitVideo(url: url)
    }
}

#Preview {
    VideoLearningView(onBack: {})
}

import SwiftUI

struct VideoLearningView: View {
    var onBack: (() -> Void)? = nil
    @StateObject private var viewModel = VideoLearningViewModel()
    @State private var urlInput = ""
    @State private var showProcessing = false
    @State private var processingVideoId: String?
    @State private var selectedVideo: VideoContent? = nil
    @FocusState private var isURLInputFocused: Bool

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
            pageGradient
                .ignoresSafeArea()
                .onTapGesture {
                    isURLInputFocused = false
                }

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
        .sheet(item: $selectedVideo) { video in
            VideoDetailView(
                video: video,
                onBack: {
                    selectedVideo = nil
                },
                onDelete: {
                    selectedVideo = nil
                    Task {
                        await viewModel.deleteVideo(videoId: video.id)
                    }
                }
            )
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(.white.opacity(0.78)))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(onBack == nil ? "LingoBuddy" : "Video Learning")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                Text("Learn English from videos")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var urlInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color(red: 0.13, green: 0.53, blue: 0.45))

                Text("添加视频")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))

                Spacer()

                if !urlInput.isEmpty {
                    Button(action: { urlInput = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    TextField("", text: $urlInput, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...3)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                        .placeholder(when: urlInput.isEmpty) {
                            Text("粘贴 B 站链接或分享内容")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary.opacity(0.6))
                        }
                        .focused($isURLInputFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            if !urlInput.isEmpty {
                                submitVideo()
                            }
                        }

                    if !urlInput.isEmpty {
                        Button(action: submitVideo) {
                            Group {
                                if viewModel.isSubmitting {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 28))
                                }
                            }
                            .foregroundStyle(Color(red: 0.13, green: 0.53, blue: 0.45))
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isSubmitting)
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        Button(action: pasteFromClipboard) {
                            VStack(spacing: 2) {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.system(size: 18))
                                Text("粘贴")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(Color(red: 0.13, green: 0.53, blue: 0.45))
                            .frame(width: 44)
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white)
                        .shadow(color: isURLInputFocused ? Color(red: 0.13, green: 0.53, blue: 0.45).opacity(0.15) : .black.opacity(0.04), radius: isURLInputFocused ? 8 : 4, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            isURLInputFocused ? Color(red: 0.13, green: 0.53, blue: 0.45).opacity(0.3) : .clear,
                            lineWidth: 2
                        )
                )

                if !urlInput.isEmpty && !isURLInputFocused {
                    Text("示例：https://b23.tv/xxx 或【标题】https://b23.tv/xxx")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.7))
                        .padding(.top, 8)
                        .padding(.horizontal, 4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

            if let error = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                    Text(error)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.red)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.red.opacity(0.08))
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.85))
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: urlInput.isEmpty)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isURLInputFocused)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.errorMessage)
    }

    private func pasteFromClipboard() {
        if let clipboardString = UIPasteboard.general.string {
            urlInput = clipboardString
            isURLInputFocused = true
        }
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
        .onTapGesture {
            isURLInputFocused = false
        }
    }

    private var videoList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(viewModel.videos) { video in
                    VideoCard(video: video, onTap: {
                        selectedVideo = video
                    })
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            isURLInputFocused = false
        }
    }

    private func submitVideo() {
        isURLInputFocused = false

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

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
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

    func deleteVideo(videoId: String) async {
        do {
            try await service.deleteVideo(videoId: videoId)
            await loadVideos()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    VideoLearningView()
}

// MARK: - View Extensions
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

import SwiftUI

struct VideoProcessingView: View {
    let videoId: String
    let onComplete: (VideoContent) -> Void

    @StateObject private var viewModel: VideoProcessingViewModel
    @Environment(\.dismiss) private var dismiss

    init(videoId: String, onComplete: @escaping (VideoContent) -> Void) {
        self.videoId = videoId
        self.onComplete = onComplete
        _viewModel = StateObject(wrappedValue: VideoProcessingViewModel(videoId: videoId))
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Progress indicator
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: viewModel.progress / 100)
                    .stroke(
                        Color(red: 0.13, green: 0.53, blue: 0.45),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear, value: viewModel.progress)

                VStack(spacing: 4) {
                    Text("\(Int(viewModel.progress))%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                }
            }

            VStack(spacing: 8) {
                Text(viewModel.statusText)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))

                Text(viewModel.statusDescription)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.red)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.1))
                    )
            }

            Spacer()

            if viewModel.isCompleted {
                Button(action: {
                    if let video = viewModel.completedVideo {
                        onComplete(video)
                    }
                    dismiss()
                }) {
                    Text("View Video")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(red: 0.13, green: 0.53, blue: 0.45))
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            }
        }
        .padding(20)
        .onAppear {
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }
}

@MainActor
final class VideoProcessingViewModel: ObservableObject {
    @Published var progress: Double = 0
    @Published var statusText = "Processing"
    @Published var statusDescription = "Downloading video..."
    @Published var errorMessage: String?
    @Published var isCompleted = false
    @Published var completedVideo: VideoContent?

    private let videoId: String
    private let service = VideoLearningService()
    private var pollingTask: Task<Void, Never>?

    init(videoId: String) {
        self.videoId = videoId
    }

    func startPolling() {
        pollingTask = Task {
            while !Task.isCancelled {
                do {
                    let status = try await service.fetchVideoStatus(videoId: videoId)

                    self.progress = Double(status.progress)

                    switch status.status {
                    case "pending":
                        statusText = "Pending"
                        statusDescription = "Waiting to start..."
                    case "processing":
                        statusText = "Processing"
                        if status.progress < 50 {
                            statusDescription = "Downloading subtitle..."
                        } else {
                            statusDescription = "Transcribing audio..."
                        }
                    case "completed":
                        statusText = "Completed"
                        statusDescription = "Video is ready!"
                        isCompleted = true

                        // Fetch complete video details
                        completedVideo = try await service.fetchVideoDetail(videoId: videoId)
                        break
                    case "failed":
                        statusText = "Failed"
                        statusDescription = "Processing failed"
                        errorMessage = status.error ?? "Unknown error"
                        break
                    default:
                        break
                    }

                    if isCompleted || errorMessage != nil {
                        break
                    }

                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                } catch {
                    errorMessage = error.localizedDescription
                    break
                }
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
    }
}

#Preview {
    VideoProcessingView(videoId: "test-id", onComplete: { _ in })
}

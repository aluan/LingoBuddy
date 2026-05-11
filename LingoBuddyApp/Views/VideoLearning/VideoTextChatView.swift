import SwiftUI

struct VideoTextChatView: View {
    let videoId: String
    let videoContext: String
    let onBack: () -> Void

    @StateObject private var viewModel: VideoTextChatViewModel
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    init(videoId: String, videoContext: String, onBack: @escaping () -> Void) {
        self.videoId = videoId
        self.videoContext = videoContext
        self.onBack = onBack
        _viewModel = StateObject(wrappedValue: VideoTextChatViewModel(videoId: videoId))
    }

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
                topBar

                messageList

                inputBar
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
                Text("Text Chat")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                Text("Ask about the video")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    if viewModel.messages.isEmpty {
                        emptyState
                    } else {
                        ForEach(viewModel.messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                    }

                    if viewModel.isLoading {
                        HStack {
                            ProgressView()
                                .tint(Color(red: 0.86, green: 0.38, blue: 0.18))
                            Text("Astra is thinking...")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.messages.count) { _ in
                if let lastMessage = viewModel.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "message.fill")
                .font(.system(size: 50))
                .foregroundStyle(Color(red: 0.13, green: 0.53, blue: 0.45).opacity(0.5))

            Text("Start chatting!")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))

            Text("Ask Astra anything about the video")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Ask about the video...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.white.opacity(0.78))
                )
                .focused($isInputFocused)

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        inputText.isEmpty ? Color.gray : Color(red: 0.13, green: 0.53, blue: 0.45)
                    )
            }
            .buttonStyle(.plain)
            .disabled(inputText.isEmpty || viewModel.isLoading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.white.opacity(0.5))
    }

    private func sendMessage() {
        let message = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }

        inputText = ""
        isInputFocused = false

        Task {
            await viewModel.sendMessage(message)
        }
    }
}

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == "user" {
                Spacer()
            }

            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: message.role == "user" ? "person.fill" : "sparkles")
                        .font(.system(size: 12, weight: .bold))
                    Text(message.role == "user" ? "You" : "Astra")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundStyle(bubbleColor)

                Text(message.text)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(bubbleColor.opacity(0.2), lineWidth: 1.5)
            )

            if message.role == "assistant" {
                Spacer()
            }
        }
    }

    private var bubbleColor: Color {
        message.role == "user" ?
            Color(red: 0.10, green: 0.45, blue: 0.74) :
            Color(red: 0.86, green: 0.38, blue: 0.18)
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String
    let text: String
}

@MainActor
final class VideoTextChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let videoId: String
    private let service = VideoLearningService()

    init(videoId: String) {
        self.videoId = videoId
    }

    func sendMessage(_ text: String) async {
        messages.append(ChatMessage(role: "user", text: text))
        isLoading = true
        errorMessage = nil

        do {
            let reply = try await service.sendChatMessage(videoId: videoId, message: text)
            messages.append(ChatMessage(role: "assistant", text: reply))
        } catch {
            errorMessage = error.localizedDescription
            messages.append(ChatMessage(
                role: "assistant",
                text: "Sorry, I couldn't process your message. Please try again."
            ))
        }

        isLoading = false
    }
}

#Preview {
    VideoTextChatView(
        videoId: "test-id",
        videoContext: "Sample video context",
        onBack: {}
    )
}

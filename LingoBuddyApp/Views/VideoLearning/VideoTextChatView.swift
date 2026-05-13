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
            pageGradient
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: dismissKeyboard)

            VStack(spacing: 0) {
                topBar

                messageList

                inputBar
            }
        }
        .task {
            await viewModel.loadMessages()
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
                    if viewModel.messages.isEmpty && !viewModel.isLoadingHistory {
                        emptyState
                    } else {
                        ForEach(viewModel.messages) { message in
                            ChatBubble(
                                message: message,
                                isStreaming: message.id == viewModel.streamingMessageID
                            )
                            .id(message.id)
                        }
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("messageListBottom")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.messages.count) { _ in
                scrollToBottom(proxy)
            }
            .onChange(of: viewModel.streamedTextVersion) { _ in
                scrollToBottom(proxy)
            }
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture(perform: dismissKeyboard)
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo("messageListBottom", anchor: .bottom)
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
        .contentShape(Rectangle())
        .onTapGesture(perform: dismissKeyboard)
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
                .submitLabel(.send)
                .onSubmit(sendMessage)

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

    private func dismissKeyboard() {
        isInputFocused = false
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private func sendMessage() {
        let message = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }

        inputText = ""
        dismissKeyboard()

        Task {
            await viewModel.sendMessage(message)
        }
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    var isStreaming = false

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

                Text(displayText)
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

    private var displayText: String {
        guard isStreaming else { return message.text }
        return message.text.isEmpty ? "▌" : "\(message.text)▌"
    }

    private var bubbleColor: Color {
        message.role == "user" ?
            Color(red: 0.10, green: 0.45, blue: 0.74) :
            Color(red: 0.86, green: 0.38, blue: 0.18)
    }
}

struct ChatMessage: Identifiable {
    let id: String
    let role: String
    var text: String

    init(id: String = UUID().uuidString, role: String, text: String) {
        self.id = id
        self.role = role
        self.text = text
    }
}

@MainActor
final class VideoTextChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var isLoadingHistory = false
    @Published var errorMessage: String?
    @Published var streamingMessageID: String?
    @Published var streamedTextVersion = 0

    private let videoId: String
    private let service = VideoLearningService()

    init(videoId: String) {
        self.videoId = videoId
    }

    func loadMessages() async {
        guard messages.isEmpty else { return }

        isLoadingHistory = true
        errorMessage = nil

        do {
            let storedMessages = try await service.fetchChatMessages(videoId: videoId)
            messages = storedMessages.map {
                ChatMessage(id: $0.id, role: $0.role, text: $0.text)
            }
            streamedTextVersion += 1
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingHistory = false
    }

    func sendMessage(_ text: String) async {
        messages.append(ChatMessage(role: "user", text: text))
        let assistantMessage = ChatMessage(role: "assistant", text: "")
        messages.append(assistantMessage)
        streamingMessageID = assistantMessage.id
        streamedTextVersion += 1
        isLoading = true
        errorMessage = nil

        do {
            for try await delta in service.streamChatMessage(videoId: videoId, message: text) {
                append(delta, toMessageID: assistantMessage.id)
            }

            if messageText(for: assistantMessage.id).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                replaceMessage(
                    assistantMessage.id,
                    with: "Sorry, I didn't receive a response. Please try again."
                )
            }
        } catch {
            errorMessage = error.localizedDescription
            replaceMessage(
                assistantMessage.id,
                with: "Sorry, I couldn't process your message. Please try again."
            )
        }

        streamingMessageID = nil
        isLoading = false
    }

    private func append(_ delta: String, toMessageID id: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].text += delta
        streamedTextVersion += 1
    }

    private func replaceMessage(_ id: String, with text: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].text = text
        streamedTextVersion += 1
    }

    private func messageText(for id: String) -> String {
        messages.first(where: { $0.id == id })?.text ?? ""
    }
}

#Preview {
    VideoTextChatView(
        videoId: "test-id",
        videoContext: "Sample video context",
        onBack: {}
    )
}

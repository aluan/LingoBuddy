import Foundation

@MainActor
final class VoiceRealtimeClient: ObservableObject {
    @Published var voiceState: VoiceInteractionState = .thinking
    @Published var childTranscript = "Tap the mic to start your quest!"
    @Published var astraReply = "Hi! Ready for a dragon quest?"
    @Published var totalStars = 18
    @Published var isConnected = false
    @Published var errorMessage: String?

    private let endpoint = URL(string: "ws://localhost:3001/voice/realtime")!
    private var task: URLSessionWebSocketTask?
    private var hasStartedSession = false

    func connect() {
        guard task == nil else { return }

        let socket = URLSession.shared.webSocketTask(with: endpoint)
        task = socket
        socket.resume()
        receiveNextMessage()
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        hasStartedSession = false
        isConnected = false
    }

    func microphoneTapped() {
        guard task != nil else {
            connect()
            return
        }

        voiceState = .thinking
        send(["type": "audio.stop"])
    }

    func cancelResponse() {
        send(["type": "response.cancel"])
    }

    private func startSessionIfNeeded() {
        guard !hasStartedSession else { return }
        hasStartedSession = true
        send(["type": "session.start"])
    }

    private func receiveNextMessage() {
        task?.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }

                switch result {
                case .success(let message):
                    self.handle(message)
                    if self.task != nil {
                        self.receiveNextMessage()
                    }

                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.isConnected = false
                    self.task = nil
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        let text: String
        switch message {
        case .string(let value):
            text = value
        case .data(let data):
            text = String(decoding: data, as: UTF8.self)
        @unknown default:
            return
        }

        guard
            let data = text.data(using: .utf8),
            let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let type = event["type"] as? String
        else {
            return
        }

        switch type {
        case "state.changed":
            handleStateChanged(event["state"] as? String)

        case "transcript.delta":
            if let text = event["text"] as? String, !text.isEmpty {
                childTranscript = text
            }

        case "assistant.text.delta":
            if let text = event["text"] as? String, !text.isEmpty {
                astraReply = text
            }

        case "reward.earned":
            if let stars = event["totalStars"] as? Int {
                totalStars = stars
            } else {
                totalStars += event["stars"] as? Int ?? 1
            }

        case "error":
            errorMessage = event["message"] as? String ?? "Realtime voice error"
            voiceState = .thinking

        default:
            break
        }
    }

    private func handleStateChanged(_ state: String?) {
        switch state {
        case "connected":
            isConnected = true
            voiceState = .listening
            startSessionIfNeeded()

        case "listening":
            voiceState = .listening

        case "speaking":
            voiceState = .speaking

        case "thinking":
            voiceState = .thinking

        default:
            break
        }
    }

    private func send(_ payload: [String: Any]) {
        guard let task else {
            errorMessage = "Voice connection is not ready"
            return
        }

        guard
            let data = try? JSONSerialization.data(withJSONObject: payload),
            let text = String(data: data, encoding: .utf8)
        else {
            return
        }

        task.send(.string(text)) { [weak self] error in
            guard let error else { return }
            Task { @MainActor in
                self?.errorMessage = error.localizedDescription
            }
        }
    }
}

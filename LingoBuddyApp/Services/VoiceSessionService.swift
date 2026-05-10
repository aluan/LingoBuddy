import Foundation

@MainActor
final class VoiceSessionService: ObservableObject {
    private let baseURL: String

    init() {
        self.baseURL = DoubaoConfig.backendBaseURL
    }

    struct SessionStartResponse: Codable {
        let sessionId: String
        let conversationId: String
        let taskId: String?
    }

    struct TranscriptRequest: Codable {
        let text: String
        let role: String
    }

    struct TranscriptResponse: Codable {
        let messageId: String
    }

    struct RewardRequest: Codable {
        let stars: Int
    }

    struct RewardResponse: Codable {
        let totalStars: Int
        let progress: Progress

        struct Progress: Codable {
            let speakingTurns: Int
            let stars: Int
        }
    }

    struct SessionEndResponse: Codable {
        let conversationId: String
        let summary: String?
    }

    func startSession(taskId: String? = nil) async throws -> SessionStartResponse {
        let url = URL(string: "\(baseURL)/voice/sessions/start")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["taskId": taskId as Any]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw VoiceSessionError.invalidResponse
        }

        return try JSONDecoder().decode(SessionStartResponse.self, from: data)
    }

    func saveTranscript(sessionId: String, text: String, role: String) async throws -> TranscriptResponse {
        let url = URL(string: "\(baseURL)/voice/sessions/\(sessionId)/transcript")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = TranscriptRequest(text: text, role: role)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw VoiceSessionError.invalidResponse
        }

        return try JSONDecoder().decode(TranscriptResponse.self, from: data)
    }

    func grantReward(sessionId: String, stars: Int) async throws -> RewardResponse {
        let url = URL(string: "\(baseURL)/voice/sessions/\(sessionId)/reward")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = RewardRequest(stars: stars)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw VoiceSessionError.invalidResponse
        }

        return try JSONDecoder().decode(RewardResponse.self, from: data)
    }

    func endSession(sessionId: String) async throws -> SessionEndResponse {
        let url = URL(string: "\(baseURL)/voice/sessions/\(sessionId)/end")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw VoiceSessionError.invalidResponse
        }

        return try JSONDecoder().decode(SessionEndResponse.self, from: data)
    }
}

enum VoiceSessionError: LocalizedError {
    case invalidResponse
    case networkError

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid response from server"
        case .networkError:
            "Network connection failed"
        }
    }
}

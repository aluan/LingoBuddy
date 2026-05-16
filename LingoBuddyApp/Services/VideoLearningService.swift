import Foundation

@MainActor
final class VideoLearningService: ObservableObject {
    @Published var videos: [VideoContent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let baseURL: String

    init() {
        self.baseURL = DoubaoConfig.backendBaseURL
    }

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            if let date = formatter.date(from: str) { return date }
            // fallback without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(str)")
        }
        return d
    }

    // MARK: - Video Management

    func submitVideo(url: String) async throws -> String {
        let endpoint = URL(string: "\(baseURL)/video-learning/submit")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["url": url]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await BackendURLSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw VideoLearningError.invalidResponse
        }

        let result = try JSONDecoder().decode(VideoSubmitResponse.self, from: data)
        return result.videoId
    }



    func submitWebpage(url: String) async throws -> String {
        let endpoint = URL(string: "\(baseURL)/video-learning/submit-webpage")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["url": url])

        let (data, response) = try await BackendURLSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw VideoLearningError.invalidResponse
        }

        let result = try JSONDecoder().decode(VideoSubmitResponse.self, from: data)
        return result.videoId
    }


    func submitText(text: String, title: String? = nil) async throws -> String {
        let endpoint = URL(string: "\(baseURL)/video-learning/submit-text")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body = ["text": text]
        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body["title"] = title
        }
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await BackendURLSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw VideoLearningError.invalidResponse
        }

        let result = try JSONDecoder().decode(VideoSubmitResponse.self, from: data)
        return result.videoId
    }

    func uploadLearningFile(data: Data, fileName: String, mimeType: String, contentType: String) async throws -> String {
        let endpoint = URL(string: "\(baseURL)/video-learning/upload")!
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(
            boundary: boundary,
            fields: ["contentType": contentType],
            fileField: "file",
            fileName: fileName,
            mimeType: mimeType,
            fileData: data
        )

        let (responseData, response) = try await BackendURLSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw VideoLearningError.invalidResponse
        }

        let result = try JSONDecoder().decode(VideoSubmitResponse.self, from: responseData)
        return result.videoId
    }

    private func multipartBody(
        boundary: String,
        fields: [String: String],
        fileField: String,
        fileName: String,
        mimeType: String,
        fileData: Data
    ) -> Data {
        var data = Data()
        for (key, value) in fields {
            data.appendString("--\(boundary)\r\n")
            data.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            data.appendString("\(value)\r\n")
        }
        data.appendString("--\(boundary)\r\n")
        data.appendString("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(fileName)\"\r\n")
        data.appendString("Content-Type: \(mimeType)\r\n\r\n")
        data.append(fileData)
        data.appendString("\r\n")
        data.appendString("--\(boundary)--\r\n")
        return data
    }

    func fetchVideoStatus(videoId: String) async throws -> VideoStatus {
        let endpoint = URL(string: "\(baseURL)/video-learning/\(videoId)/status")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"

        let (data, response) = try await BackendURLSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw VideoLearningError.invalidResponse
        }

        return try JSONDecoder().decode(VideoStatus.self, from: data)
    }

    func fetchVideoList() async throws -> [VideoContent] {
        let endpoint = URL(string: "\(baseURL)/video-learning/list")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"

        let (data, response) = try await BackendURLSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw VideoLearningError.invalidResponse
        }

        let result = try decoder.decode(VideoListResponse.self, from: data)
        return result.videos
    }

    func fetchVideoDetail(videoId: String) async throws -> VideoContent {
        let endpoint = URL(string: "\(baseURL)/video-learning/\(videoId)")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"

        let (data, response) = try await BackendURLSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw VideoLearningError.invalidResponse
        }

        return try decoder.decode(VideoContent.self, from: data)
    }

    func deleteVideo(videoId: String) async throws {
        let endpoint = URL(string: "\(baseURL)/video-learning/\(videoId)")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "DELETE"

        let (_, response) = try await BackendURLSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw VideoLearningError.invalidResponse
        }
    }

    // MARK: - Chat


    func fetchChatMessages(videoId: String) async throws -> [StoredChatMessage] {
        let endpoint = URL(string: "\(baseURL)/video-learning/\(videoId)/chat/messages")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"

        let (data, response) = try await BackendURLSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw VideoLearningError.invalidResponse
        }

        let result = try decoder.decode(ChatHistoryResponse.self, from: data)
        return result.messages
    }

    func sendChatMessage(videoId: String, message: String) async throws -> String {
        var reply = ""
        for try await delta in streamChatMessage(videoId: videoId, message: message) {
            reply += delta
        }
        return reply
    }

    nonisolated func streamChatMessage(videoId: String, message: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let endpoint = await self.chatStreamEndpoint(videoId: videoId)
                    var request = URLRequest(url: endpoint)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                    let body = ["message": message]
                    request.httpBody = try JSONEncoder().encode(body)

                    let (bytes, response) = try await BackendURLSession.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode) else {
                        throw VideoLearningError.invalidResponse
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }

                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }
                        guard !payload.isEmpty else { continue }

                        let event = try JSONDecoder().decode(ChatStreamEvent.self, from: Data(payload.utf8))
                        if let error = event.error {
                            throw VideoLearningError.serverError(error)
                        }
                        if let delta = event.delta, !delta.isEmpty {
                            continuation.yield(delta)
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }


    private func chatStreamEndpoint(videoId: String) -> URL {
        URL(string: "\(baseURL)/video-learning/\(videoId)/chat/stream")!
    }

    // MARK: - Quiz

    func generateQuiz(videoId: String, difficulty: String, questionCount: Int) async throws -> Quiz {
        let endpoint = URL(string: "\(baseURL)/video-learning/\(videoId)/generate-quiz")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["difficulty": difficulty, "questionCount": questionCount] as [String : Any]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await BackendURLSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw VideoLearningError.invalidResponse
        }

        return try decoder.decode(Quiz.self, from: data)
    }

    func fetchQuizzes(videoId: String) async throws -> [Quiz] {
        let endpoint = URL(string: "\(baseURL)/video-learning/\(videoId)/quizzes")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"

        let (data, response) = try await BackendURLSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw VideoLearningError.invalidResponse
        }

        let result = try decoder.decode(QuizListResponse.self, from: data)
        return result.quizzes
    }

    func submitQuiz(quizId: String, answers: [QuizAnswer]) async throws -> QuizResult {
        let endpoint = URL(string: "\(baseURL)/video-learning/quizzes/\(quizId)/submit")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["answers": answers]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await BackendURLSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw VideoLearningError.invalidResponse
        }

        return try JSONDecoder().decode(QuizResult.self, from: data)
    }
}

enum VideoLearningError: LocalizedError {
    case invalidResponse
    case networkError
    case decodingError
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError:
            return "Network connection failed"
        case .decodingError:
            return "Failed to decode response"
        case .serverError(let message):
            return message
        }
    }
}


private extension Data {
    mutating func appendString(_ string: String) {
        append(Data(string.utf8))
    }
}

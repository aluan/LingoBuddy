import Foundation

@MainActor
final class KnowledgeService: ObservableObject {
    @Published var home: KnowledgeHomeResponse?
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
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(str)")
        }
        return d
    }

    func fetchHome() async {
        isLoading = true
        errorMessage = nil
        do {
            home = try await fetchHomeResponse()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func fetchHomeResponse() async throws -> KnowledgeHomeResponse {
        let endpoint = URL(string: "\(baseURL)/knowledge/home")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        let (data, response) = try await BackendURLSession.data(for: request)
        try validate(response)
        return try decoder.decode(KnowledgeHomeResponse.self, from: data)
    }

    func search(query: String) async throws -> [KnowledgeNode] {
        var components = URLComponents(string: "\(baseURL)/knowledge/search")!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        let (data, response) = try await BackendURLSession.data(for: request)
        try validate(response)
        return try decoder.decode(KnowledgeSearchResponse.self, from: data).nodes
    }

    func fetchNodeDetail(nodeId: String) async throws -> KnowledgeNodeDetailResponse {
        let endpoint = URL(string: "\(baseURL)/knowledge/nodes/\(nodeId)")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        let (data, response) = try await BackendURLSession.data(for: request)
        try validate(response)
        return try decoder.decode(KnowledgeNodeDetailResponse.self, from: data)
    }

    func buildVideoKnowledge(videoId: String) async throws -> BuildKnowledgeResponse {
        let endpoint = URL(string: "\(baseURL)/video-learning/\(videoId)/build-knowledge")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)
        let (data, response) = try await BackendURLSession.data(for: request)
        try validate(response)
        return try decoder.decode(BuildKnowledgeResponse.self, from: data)
    }

    func fetchVideoKnowledge(videoId: String) async throws -> [KnowledgeNode] {
        let endpoint = URL(string: "\(baseURL)/video-learning/\(videoId)/knowledge-note")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        let (data, response) = try await BackendURLSession.data(for: request)
        try validate(response)
        return try decoder.decode(VideoKnowledgeResponse.self, from: data).nodes
    }

    private func validate(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw VideoLearningError.invalidResponse
        }
    }
}

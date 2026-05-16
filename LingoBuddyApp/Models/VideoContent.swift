import Foundation

struct VideoContent: Codable, Identifiable {
    let id: String
    let url: String
    let videoId: String
    let title: String
    let duration: Double
    let thumbnailUrl: String?
    let contentType: String?
    let platform: String?
    let transcriptStatus: String
    let transcriptSource: String?
    let transcriptText: String?
    let conversationCount: Int
    let quizCount: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case url
        case videoId
        case title
        case duration
        case thumbnailUrl
        case contentType
        case platform
        case transcriptStatus
        case transcriptSource
        case transcriptText
        case conversationCount
        case quizCount
        case createdAt
    }
}

struct VideoStatus: Codable {
    let status: String
    let progress: Int
    let transcriptText: String?
    let transcriptSource: String?
    let error: String?
}

struct VideoSubmitResponse: Codable {
    let videoId: String
    let status: String
}

struct VideoListResponse: Codable {
    let videos: [VideoContent]
}

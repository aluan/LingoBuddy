import Foundation

struct KnowledgeNode: Codable, Identifiable, Hashable {
    let id: String
    let type: String
    let title: String
    let body: String
    let key: String?
    let tags: [String]
    let sourceVideoId: String?
    let metadata: [String: JSONValue]?
    let createdAt: Date?
    let updatedAt: Date?

    var displayType: String {
        switch type {
        case "video_note": return "Video"
        case "vocabulary": return "Word"
        case "sentence": return "Sentence"
        case "quiz_mistake": return "Mistake"
        case "question": return "Question"
        default: return type
        }
    }

    var iconName: String {
        switch type {
        case "video_note": return "play.rectangle.fill"
        case "vocabulary": return "textformat.abc"
        case "sentence": return "quote.bubble.fill"
        case "quiz_mistake": return "exclamationmark.triangle.fill"
        case "question": return "questionmark.bubble.fill"
        default: return "circle.hexagongrid.fill"
        }
    }
}

struct KnowledgeLink: Codable, Identifiable, Hashable {
    let id: String
    let relation: String
    let direction: String
    let node: KnowledgeNode
}

struct KnowledgeHomeResponse: Codable {
    let recentNodes: [KnowledgeNode]
    let videoNotes: [KnowledgeNode]
    let vocabulary: [KnowledgeNode]
    let mistakes: [KnowledgeNode]
}

struct KnowledgeSearchResponse: Codable {
    let nodes: [KnowledgeNode]
}

struct KnowledgeNodeDetailResponse: Codable {
    let node: KnowledgeNode
    let links: [KnowledgeLink]
}

struct VideoKnowledgeResponse: Codable {
    let nodes: [KnowledgeNode]
}

struct BuildKnowledgeResponse: Codable {
    let videoNote: KnowledgeNode
    let created: BuildKnowledgeCounts
    let nodes: [KnowledgeNode]
}

struct BuildKnowledgeCounts: Codable {
    let vocabulary: Int
    let sentences: Int
    let questions: Int
    let mistakes: Int
}

enum JSONValue: Codable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }
}

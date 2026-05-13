import Foundation

struct Quiz: Codable, Identifiable {
    let id: String
    let videoId: String
    let difficulty: String
    let questions: [QuizQuestion]
    let submitted: Bool
    let score: Int?
    let correctCount: Int?
    let starsEarned: Int?
    let createdAt: Date
    let answers: [StoredQuizAnswer]?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case videoId
        case difficulty
        case questions
        case submitted
        case score
        case correctCount
        case starsEarned
        case createdAt
        case answers
    }

    func toQuizResult() -> QuizResult? {
        guard submitted, let score, let correctCount, let answers else { return nil }
        let results = answers.map { a -> QuizAnswerResult in
            let correct = questions.first(where: { $0.id == a.questionId })?.correctAnswer == a.answer
            return QuizAnswerResult(questionId: a.questionId, answer: a.answer, isCorrect: correct)
        }
        return QuizResult(quizId: id, score: score, correctAnswers: correctCount,
                          totalQuestions: questions.count, answers: results)
    }
}

struct StoredQuizAnswer: Codable {
    let questionId: String
    let answer: String
}

struct QuizQuestion: Codable, Identifiable {
    let id: String
    let type: String
    let question: String
    let options: [String]?
    let correctAnswer: String
    let explanation: String?

    enum CodingKeys: String, CodingKey {
        case id = "questionId"
        case type
        case question
        case options
        case correctAnswer
        case explanation
    }
}

struct QuizAnswer: Codable {
    let questionId: String
    let answer: String
}

struct QuizResult: Codable, Identifiable {
    var id: String { quizId }
    let quizId: String
    let score: Int
    let correctAnswers: Int
    let totalQuestions: Int
    let answers: [QuizAnswerResult]

    var scorePercentage: Double {
        guard totalQuestions > 0 else { return 0 }
        return Double(correctAnswers) / Double(totalQuestions) * 100
    }

    enum CodingKeys: String, CodingKey {
        case quizId
        case score
        case correctAnswers = "correctCount"
        case totalQuestions = "totalCount"
        case answers
    }
}

struct QuizAnswerResult: Codable {
    let questionId: String
    let answer: String
    let isCorrect: Bool
}

struct QuizListResponse: Codable {
    let quizzes: [Quiz]
}

struct ChatResponse: Codable {
    let reply: String
}

struct ChatStreamEvent: Codable {
    let delta: String?
    let done: Bool?
    let conversationId: String?
    let messageId: String?
    let error: String?
}

struct ChatHistoryResponse: Codable {
    let conversationId: String
    let messages: [StoredChatMessage]
}

struct StoredChatMessage: Codable, Identifiable {
    let id: String
    let role: String
    let text: String
    let createdAt: Date?
}

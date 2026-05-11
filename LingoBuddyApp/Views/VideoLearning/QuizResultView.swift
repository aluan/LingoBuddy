import SwiftUI

struct QuizResultView: View {
    let result: QuizResult
    let quiz: Quiz
    let onDismiss: () -> Void

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

                ScrollView {
                    VStack(spacing: 24) {
                        scoreCard

                        performanceBreakdown

                        questionReview
                    }
                    .padding(20)
                }

                Button(action: onDismiss) {
                    Text("Done")
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
                .padding(.vertical, 12)
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(red: 0.86, green: 0.38, blue: 0.18))
                .frame(width: 42, height: 42)
                .background(Circle().fill(.white.opacity(0.78)))

            VStack(alignment: .leading, spacing: 2) {
                Text("Quiz Results")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                Text("See how you did")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var scoreCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 140, height: 140)

                Circle()
                    .trim(from: 0, to: result.scorePercentage / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: result.scorePercentage)

                VStack(spacing: 4) {
                    Text("\(Int(result.scorePercentage))%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))

                    Text(performanceLabel)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor)
                }
            }

            VStack(spacing: 8) {
                Text("\(result.correctAnswers) out of \(result.totalQuestions) correct")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))

                Text("Score: \(result.score) points")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.85))
        )
    }

    private var performanceBreakdown: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))

            HStack(spacing: 12) {
                StatBox(
                    icon: "checkmark.circle.fill",
                    value: "\(result.correctAnswers)",
                    label: "Correct",
                    color: Color(red: 0.13, green: 0.53, blue: 0.45)
                )

                StatBox(
                    icon: "xmark.circle.fill",
                    value: "\(result.totalQuestions - result.correctAnswers)",
                    label: "Wrong",
                    color: Color(red: 0.78, green: 0.16, blue: 0.12)
                )

                StatBox(
                    icon: "star.fill",
                    value: "\(result.score)",
                    label: "Points",
                    color: Color(red: 0.86, green: 0.38, blue: 0.18)
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.78))
        )
    }

    private var questionReview: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Review Answers")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))

            ForEach(Array(quiz.questions.enumerated()), id: \.element.id) { index, question in
                QuestionReviewCard(
                    question: question,
                    questionNumber: index + 1,
                    userAnswer: result.answers.first(where: { $0.questionId == question.id })?.answer,
                    isCorrect: result.answers.first(where: { $0.questionId == question.id })?.isCorrect ?? false
                )
            }
        }
    }

    private var scoreColor: Color {
        if result.scorePercentage >= 80 {
            return Color(red: 0.13, green: 0.53, blue: 0.45)
        } else if result.scorePercentage >= 60 {
            return Color(red: 0.86, green: 0.52, blue: 0.14)
        } else {
            return Color(red: 0.78, green: 0.16, blue: 0.12)
        }
    }

    private var performanceLabel: String {
        if result.scorePercentage >= 80 {
            return "Excellent!"
        } else if result.scorePercentage >= 60 {
            return "Good Job!"
        } else {
            return "Keep Trying!"
        }
    }
}

struct StatBox: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))

            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color.opacity(0.1))
        )
    }
}

struct QuestionReviewCard: View {
    let question: QuizQuestion
    let questionNumber: Int
    let userAnswer: String?
    let isCorrect: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Q\(questionNumber)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color(red: 0.86, green: 0.38, blue: 0.18)))

                Spacer()

                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(isCorrect ? Color(red: 0.13, green: 0.53, blue: 0.45) : Color(red: 0.78, green: 0.16, blue: 0.12))
            }

            Text(question.question)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                .fixedSize(horizontal: false, vertical: true)

            if let userAnswer = userAnswer {
                HStack(spacing: 8) {
                    Text("Your answer:")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(userAnswer)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(isCorrect ? Color(red: 0.13, green: 0.53, blue: 0.45) : Color(red: 0.78, green: 0.16, blue: 0.12))
                }
            }

            if !isCorrect {
                HStack(spacing: 8) {
                    Text("Correct answer:")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(question.correctAnswer)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.13, green: 0.53, blue: 0.45))
                }
            }

            if let explanation = question.explanation {
                Text(explanation)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.gray.opacity(0.08))
                    )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isCorrect ? Color(red: 0.13, green: 0.53, blue: 0.45).opacity(0.3) : Color(red: 0.78, green: 0.16, blue: 0.12).opacity(0.3),
                    lineWidth: 1.5
                )
        )
    }
}

#Preview {
    QuizResultView(
        result: QuizResult(
            quizId: "1",
            score: 80,
            totalQuestions: 5,
            correctAnswers: 4,
            answers: [
                QuizAnswerResult(questionId: "1", answer: "Paris", isCorrect: true),
                QuizAnswerResult(questionId: "2", answer: "London", isCorrect: false)
            ]
        ),
        quiz: Quiz(
            id: "1",
            videoId: "video1",
            questions: [
                QuizQuestion(
                    id: "1",
                    question: "What is the capital of France?",
                    type: "multiple_choice",
                    options: ["Paris", "London", "Berlin", "Madrid"],
                    correctAnswer: "Paris",
                    explanation: "Paris is the capital and largest city of France."
                )
            ],
            difficulty: "easy",
            createdAt: Date()
        ),
        onDismiss: {}
    )
}

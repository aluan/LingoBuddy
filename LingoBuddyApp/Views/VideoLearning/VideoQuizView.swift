import SwiftUI

struct VideoQuizView: View {
    let videoId: String
    let onBack: () -> Void

    @StateObject private var viewModel: VideoQuizViewModel
    @State private var showResult = false

    init(videoId: String, onBack: @escaping () -> Void) {
        self.videoId = videoId
        self.onBack = onBack
        _viewModel = StateObject(wrappedValue: VideoQuizViewModel(videoId: videoId))
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

                if viewModel.quiz == nil {
                    quizSetupView
                } else {
                    quizView
                }
            }
        }
        .sheet(isPresented: $showResult) {
            if let result = viewModel.quizResult, let quiz = viewModel.quiz {
                QuizResultView(
                    result: result,
                    quiz: quiz,
                    onDismiss: {
                        showResult = false
                        onBack()
                    }
                )
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
                Text("Video Quiz")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                Text("Test your knowledge")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var quizSetupView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color(red: 0.86, green: 0.38, blue: 0.18))

            VStack(spacing: 12) {
                Text("Generate Quiz")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))

                Text("Choose difficulty and number of questions")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Difficulty")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))

                    Picker("Difficulty", selection: $viewModel.selectedDifficulty) {
                        Text("Easy").tag("easy")
                        Text("Medium").tag("medium")
                        Text("Hard").tag("hard")
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Questions: \(viewModel.questionCount)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))

                    Stepper("", value: $viewModel.questionCount, in: 3...10)
                        .labelsHidden()
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white.opacity(0.78))
            )

            Button(action: {
                Task {
                    await viewModel.generateQuiz()
                }
            }) {
                if viewModel.isGenerating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Generate Quiz")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.86, green: 0.38, blue: 0.18))
            )
            .disabled(viewModel.isGenerating)

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var quizView: some View {
        VStack(spacing: 0) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))

                    Rectangle()
                        .fill(Color(red: 0.86, green: 0.38, blue: 0.18))
                        .frame(width: geometry.size.width * viewModel.progress)
                        .animation(.linear, value: viewModel.progress)
                }
            }
            .frame(height: 4)

            ScrollView {
                VStack(spacing: 16) {
                    if let quiz = viewModel.quiz {
                        ForEach(Array(quiz.questions.enumerated()), id: \.element.id) { index, question in
                            QuestionCard(
                                question: question,
                                questionNumber: index + 1,
                                totalQuestions: quiz.questions.count,
                                selectedAnswer: viewModel.answers[question.id],
                                onSelect: { answer in
                                    viewModel.answers[question.id] = answer
                                }
                            )
                        }
                    }
                }
                .padding(20)
            }

            // Submit button
            Button(action: submitQuiz) {
                if viewModel.isSubmitting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Submit Quiz")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(viewModel.allQuestionsAnswered ? Color(red: 0.13, green: 0.53, blue: 0.45) : Color.gray)
            )
            .disabled(!viewModel.allQuestionsAnswered || viewModel.isSubmitting)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    private func submitQuiz() {
        Task {
            await viewModel.submitQuiz()
            if viewModel.quizResult != nil {
                showResult = true
            }
        }
    }
}

@MainActor
final class VideoQuizViewModel: ObservableObject {
    @Published var quiz: Quiz?
    @Published var answers: [String: String] = [:]
    @Published var selectedDifficulty = "easy"
    @Published var questionCount = 5
    @Published var isGenerating = false
    @Published var isSubmitting = false
    @Published var quizResult: QuizResult?
    @Published var errorMessage: String?

    private let videoId: String
    private let service = VideoLearningService()

    init(videoId: String) {
        self.videoId = videoId
    }

    var allQuestionsAnswered: Bool {
        guard let quiz = quiz else { return false }
        return quiz.questions.allSatisfy { answers[$0.id] != nil }
    }

    var progress: Double {
        guard let quiz = quiz else { return 0 }
        let answered = quiz.questions.filter { answers[$0.id] != nil }.count
        return Double(answered) / Double(quiz.questions.count)
    }

    func generateQuiz() async {
        isGenerating = true
        errorMessage = nil

        do {
            quiz = try await service.generateQuiz(
                videoId: videoId,
                difficulty: selectedDifficulty,
                questionCount: questionCount
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isGenerating = false
    }

    func submitQuiz() async {
        guard let quiz = quiz else { return }

        isSubmitting = true
        errorMessage = nil

        let quizAnswers = answers.map { QuizAnswer(questionId: $0.key, answer: $0.value) }

        do {
            quizResult = try await service.submitQuiz(quizId: quiz.id, answers: quizAnswers)
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }
}

#Preview {
    VideoQuizView(videoId: "test-id", onBack: {})
}

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
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showResult) {
            if let result = viewModel.quizResult, let quiz = viewModel.quiz {
                QuizResultView(result: result, quiz: quiz, onDismiss: {
                    showResult = false
                    viewModel.returnToListAfterResult()
                })
            }
        }
        .sheet(item: $viewModel.selectedHistoryResult) { result in
            if let quiz = viewModel.history.first(where: { $0.id == result.quizId }) {
                QuizResultView(result: result, quiz: quiz, onDismiss: {
                    viewModel.selectedHistoryResult = nil
                })
            }
        }
        .task {
            await viewModel.loadHistory()
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
        quizListView
    }

    private var quizListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                quizListHero

                if viewModel.isLoadingHistory {
                    loadingHistoryCard
                } else if viewModel.history.isEmpty {
                    emptyQuizCard
                } else {
                    quizHistoryList
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 120)
        }
        .overlay(alignment: .bottom) {
            generateQuizBar
        }
        .sheet(isPresented: $viewModel.showGenerator) {
            generateQuizSheet
                .presentationDetents([.height(430)])
                .presentationDragIndicator(.visible)
        }
        .refreshable {
            await viewModel.loadHistory()
        }
    }

    private var quizListHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(red: 0.86, green: 0.38, blue: 0.18).opacity(0.16))
                        .frame(width: 58, height: 58)

                    Image(systemName: "list.bullet.clipboard.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color(red: 0.86, green: 0.38, blue: 0.18))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Quiz Library")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))

                    Text("先从已生成的练习开始；需要新题时，点下方按钮生成。")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                QuizMetricPill(
                    value: "\(viewModel.history.count)",
                    label: "Quizzes",
                    icon: "tray.full.fill",
                    color: Color(red: 0.12, green: 0.45, blue: 0.78)
                )

                QuizMetricPill(
                    value: "\(viewModel.completedQuizCount)",
                    label: "Done",
                    icon: "checkmark.seal.fill",
                    color: Color(red: 0.13, green: 0.53, blue: 0.45)
                )

                QuizMetricPill(
                    value: viewModel.bestScoreText,
                    label: "Best",
                    icon: "star.fill",
                    color: Color(red: 0.91, green: 0.62, blue: 0.15)
                )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.white.opacity(0.82))
                .shadow(color: Color(red: 0.12, green: 0.19, blue: 0.24).opacity(0.08), radius: 22, x: 0, y: 12)
        )
    }

    private var loadingHistoryCard: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Color(red: 0.86, green: 0.38, blue: 0.18))
            Text("Loading quizzes…")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.78))
        )
    }

    private var emptyQuizCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(Color(red: 0.86, green: 0.38, blue: 0.18))
                .padding(.top, 8)

            VStack(spacing: 8) {
                Text("No quizzes yet")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                Text("生成一套题后，这里会优先展示 Quiz 列表，方便复习和查看成绩。")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: { viewModel.showGenerator = true }) {
                Label("Generate Quiz", systemImage: "plus.circle.fill")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 46)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(red: 0.86, green: 0.38, blue: 0.18))
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.white.opacity(0.78))
        )
    }

    private var quizHistoryList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Past Quizzes")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))

                Spacer()

                Text("Pull to refresh")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            ForEach(viewModel.history) { quiz in
                QuizHistoryRow(
                    quiz: quiz,
                    actionTitle: quiz.submitted ? "Result" : "Resume",
                    actionColor: quiz.submitted
                        ? Color(red: 0.13, green: 0.53, blue: 0.45)
                        : Color(red: 0.86, green: 0.38, blue: 0.18),
                    onTap: { openQuiz(quiz) }
                )
            }
        }
    }

    private var generateQuizBar: some View {
        VStack(spacing: 10) {
            if let error = viewModel.errorMessage, !viewModel.showGenerator {
                Text(error)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(.white.opacity(0.92))
                    )
            }

            Button(action: { viewModel.showGenerator = true }) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                    Text("Generate Quiz")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Spacer()
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .frame(height: 58)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(red: 0.86, green: 0.38, blue: 0.18))
                        .shadow(color: Color(red: 0.86, green: 0.38, blue: 0.18).opacity(0.28), radius: 18, x: 0, y: 10)
                )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isGenerating)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 18)
        .background(
            LinearGradient(
                colors: [Color.clear, Color(red: 0.82, green: 0.94, blue: 0.98).opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private var generateQuizSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Generate Quiz")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                Text("选择难度和题量，生成后会立即进入答题。")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
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

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Questions")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                    Spacer()
                    Text("\(viewModel.questionCount)")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.86, green: 0.38, blue: 0.18))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule(style: .continuous).fill(Color(red: 0.86, green: 0.38, blue: 0.18).opacity(0.13)))
                }

                Stepper("", value: $viewModel.questionCount, in: 3...10)
                    .labelsHidden()
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(red: 0.95, green: 0.99, blue: 0.96)))

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button(action: {
                Task {
                    await viewModel.generateQuiz()
                }
            }) {
                HStack(spacing: 10) {
                    if viewModel.isGenerating {
                        ProgressView().tint(.white)
                        Text("Generating…")
                    } else {
                        Image(systemName: "wand.and.stars")
                        Text("Generate & Start")
                    }
                }
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(red: 0.86, green: 0.38, blue: 0.18))
                )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isGenerating)
        }
        .padding(22)
        .background(Color(red: 0.95, green: 0.99, blue: 0.96))
    }

    private var historySection: some View {
        quizHistoryList
    }


    private func openQuiz(_ quiz: Quiz) {
        if let result = quiz.toQuizResult() {
            viewModel.selectedHistoryResult = result
        } else {
            viewModel.startExistingQuiz(quiz)
        }
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
    @Published var history: [Quiz] = []
    @Published var isLoadingHistory = false
    @Published var selectedHistoryResult: QuizResult?
    @Published var showGenerator = false

    private let videoId: String
    private let service = VideoLearningService()

    init(videoId: String) {
        self.videoId = videoId
    }

    func loadHistory() async {
        isLoadingHistory = true
        do {
            history = try await service.fetchQuizzes(videoId: videoId)
        } catch {
            print("[VideoQuiz] loadHistory error: \(error)")
        }
        isLoadingHistory = false
    }

    var completedQuizCount: Int {
        history.filter(\.submitted).count
    }

    var bestScoreText: String {
        let best = history.compactMap(\.score).max()
        return best.map { "\($0)%" } ?? "—"
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

    func startExistingQuiz(_ selectedQuiz: Quiz) {
        quiz = selectedQuiz
        quizResult = nil
        answers = [:]
        errorMessage = nil
    }

    func returnToListAfterResult() {
        quiz = nil
        answers = [:]
        quizResult = nil
        Task { await loadHistory() }
    }

    func generateQuiz() async {
        isGenerating = true
        errorMessage = nil

        do {
            answers = [:]
            quizResult = nil
            quiz = try await service.generateQuiz(
                videoId: videoId,
                difficulty: selectedDifficulty,
                questionCount: questionCount
            )
            showGenerator = false
            await loadHistory()
        } catch {
            print("[VideoQuiz] generateQuiz error: \(error)")
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
        if quizResult != nil {
            await loadHistory()
        }
    }
}

private struct QuizMetricPill: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .textCase(.uppercase)
            }
            .foregroundStyle(color)

            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(color.opacity(0.11))
        )
    }
}

private struct QuizHistoryRow: View {
    let quiz: Quiz
    let actionTitle: String
    let actionColor: Color
    let onTap: () -> Void

    private var statusColor: Color {
        guard quiz.submitted, let score = quiz.score else { return Color(red: 0.86, green: 0.38, blue: 0.18) }
        return score >= 60 ? Color(red: 0.13, green: 0.53, blue: 0.45) : Color(red: 0.86, green: 0.38, blue: 0.18)
    }

    private var statusText: String {
        if quiz.submitted, let score = quiz.score { return "\(score)%" }
        return "Draft"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.13))
                        .frame(width: 52, height: 52)

                    Image(systemName: quiz.submitted ? "checkmark.seal.fill" : "pencil.and.list.clipboard")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(statusColor)
                }

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Text(quiz.difficulty.capitalized)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))

                        Text("\(quiz.questions.count) Qs")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(Color(red: 0.12, green: 0.45, blue: 0.78))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule(style: .continuous).fill(Color(red: 0.12, green: 0.45, blue: 0.78).opacity(0.11)))
                    }

                    Text(quiz.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 8) {
                    Text(statusText)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(statusColor)

                    HStack(spacing: 4) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(actionColor)
                }
            }
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.white.opacity(0.82))
                    .shadow(color: Color(red: 0.12, green: 0.19, blue: 0.24).opacity(0.05), radius: 14, x: 0, y: 8)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VideoQuizView(videoId: "test-id", onBack: {})
}

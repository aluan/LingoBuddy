import SwiftUI

struct QuestionCard: View {
    let question: QuizQuestion
    let questionNumber: Int
    let totalQuestions: Int
    let selectedAnswer: String?
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Question header
            HStack {
                Text("Question \(questionNumber)/\(totalQuestions)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color(red: 0.86, green: 0.38, blue: 0.18))
                    )

                Spacer()

                Image(systemName: questionTypeIcon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(red: 0.86, green: 0.38, blue: 0.18))
            }

            // Question text
            Text(question.question)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                .fixedSize(horizontal: false, vertical: true)

            // Options
            VStack(spacing: 10) {
                ForEach(question.options ?? [], id: \.self) { option in
                    OptionButton(
                        text: option,
                        isSelected: selectedAnswer == option,
                        onTap: { onSelect(option) }
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(red: 0.86, green: 0.38, blue: 0.18).opacity(0.2), lineWidth: 1.5)
        )
    }

    private var questionTypeIcon: String {
        switch question.type {
        case "multiple_choice":
            return "list.bullet.circle.fill"
        case "true_false":
            return "checkmark.circle.fill"
        case "fill_blank":
            return "text.cursor"
        default:
            return "questionmark.circle.fill"
        }
    }
}

struct OptionButton: View {
    let text: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(isSelected ? Color(red: 0.13, green: 0.53, blue: 0.45) : Color.gray.opacity(0.4))

                Text(text)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color(red: 0.13, green: 0.53, blue: 0.45).opacity(0.1) : Color.gray.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? Color(red: 0.13, green: 0.53, blue: 0.45) : Color.gray.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    QuestionCard(
        question: QuizQuestion(
            id: "1",
            type: "multiple_choice",
            question: "What is the capital of France?",
            options: ["Paris", "London", "Berlin", "Madrid"],
            correctAnswer: "Paris",
            explanation: "Paris is the capital and largest city of France."
        ),
        questionNumber: 1,
        totalQuestions: 5,
        selectedAnswer: nil,
        onSelect: { _ in }
    )
    .padding()
}

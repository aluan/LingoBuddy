import SwiftUI

struct MeView: View {
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

            VStack(spacing: 28) {
                header

                statsRow

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.13, green: 0.53, blue: 0.45).opacity(0.15))
                    .frame(width: 88, height: 88)
                Image(systemName: "person.fill")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(Color(red: 0.13, green: 0.53, blue: 0.45))
            }

            VStack(spacing: 4) {
                Text("My Profile")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                Text("Keep learning every day!")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 20)
    }

    private var statsRow: some View {
        HStack(spacing: 14) {
            statCard(value: "18", label: "Stars", icon: "star.fill",
                     tint: Color(red: 0.94, green: 0.56, blue: 0.13))
            statCard(value: "4", label: "Day Streak", icon: "flame.fill",
                     tint: Color(red: 0.90, green: 0.28, blue: 0.18))
        }
    }

    private func statCard(value: String, label: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.white.opacity(0.78)))
    }
}

#Preview {
    MeView()
}

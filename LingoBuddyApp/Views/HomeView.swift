import SwiftUI

struct HomeView: View {
    let onStartSpeaking: () -> Void

    private let morningGradient = LinearGradient(
        colors: [
            Color(red: 0.95, green: 0.99, blue: 0.96),
            Color(red: 0.83, green: 0.94, blue: 0.98),
            Color(red: 0.99, green: 0.93, blue: 0.78)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            morningGradient.ignoresSafeArea()

            VStack(spacing: 24) {
                header

                VStack(alignment: .leading, spacing: 18) {
                    Text("Today's Quest")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    Text("Practice a tiny English adventure with Astra.")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        Label("5 min", systemImage: "clock")
                        Label("Speaking", systemImage: "waveform")
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.33, green: 0.43, blue: 0.47))

                    Button(action: onStartSpeaking) {
                        HStack(spacing: 10) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 20, weight: .bold))
                            Text("Start Talking")
                                .font(.system(size: 19, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.13, green: 0.53, blue: 0.45))
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Starts the voice chat adventure")
                }
                .padding(22)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.white.opacity(0.82))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.9), lineWidth: 1)
                )

                HStack(spacing: 14) {
                    miniStat(title: "Stars", value: "18", icon: "star.fill", tint: Color(red: 0.94, green: 0.56, blue: 0.13))
                    miniStat(title: "Streak", value: "4", icon: "flame.fill", tint: Color(red: 0.90, green: 0.28, blue: 0.18))
                }

                Spacer(minLength: 0)

                tabBar
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 10)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.13, green: 0.53, blue: 0.45))
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 3) {
                Text("LingoBuddy")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                Text("Ready for a short quest")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: {}) {
                Image(systemName: "bell")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(.white.opacity(0.75)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Notifications")
        }
    }

    private func miniStat(title: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(Circle().fill(tint.opacity(0.14)))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.68))
        )
    }

    private var tabBar: some View {
        HStack {
            tabItem("Home", "house.fill", isSelected: true)
            tabItem("Dragons", "sparkle.magnifyingglass", isSelected: false)
            tabItem("Quests", "checklist", isSelected: false)
            tabItem("Me", "person.crop.circle", isSelected: false)
        }
        .padding(8)
        .background(
            Capsule()
                .fill(.white.opacity(0.88))
                .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 8)
        )
    }

    private func tabItem(_ title: String, _ icon: String, isSelected: Bool) -> some View {
        Button(action: {}) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(isSelected ? Color(red: 0.13, green: 0.53, blue: 0.45) : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

#Preview {
    HomeView(onStartSpeaking: {})
}

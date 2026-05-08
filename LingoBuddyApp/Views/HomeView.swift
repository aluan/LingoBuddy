import SwiftUI

struct HomeView: View {
    let onStartSpeaking: () -> Void
    @State private var pressedTalk = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                DesignImageBackground(imageName: "home")

                Button(action: onStartSpeaking) {
                    RoundedRectangle(cornerRadius: proxy.size.width * 0.10)
                        .fill(Color.white.opacity(0.001))
                }
                .buttonStyle(.plain)
                .frame(
                    width: proxy.size.width * 0.86,
                    height: proxy.size.height * 0.105
                )
                .contentShape(RoundedRectangle(cornerRadius: proxy.size.width * 0.09))
                .position(x: proxy.size.width * 0.50, y: proxy.size.height * 0.825)
                .accessibilityLabel("Talk with Astra")
                .accessibilityHint("Starts the voice chat adventure")
                .scaleEffect(pressedTalk ? 0.985 : 1)
                .onLongPressGesture(
                    minimumDuration: 0,
                    maximumDistance: 120,
                    pressing: { isPressing in pressedTalk = isPressing },
                    perform: {}
                )

                bottomTabHitAreas(in: proxy)
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func bottomTabHitAreas(in proxy: GeometryProxy) -> some View {
        let y = proxy.size.height * 0.955
        let width = proxy.size.width * 0.20
        let height = proxy.size.height * 0.08

        Group {
            Button(action: {}) { Rectangle().fill(Color.white.opacity(0.001)) }
                .accessibilityLabel("Home")
                .position(x: proxy.size.width * 0.16, y: y)

            Button(action: {}) { Rectangle().fill(Color.white.opacity(0.001)) }
                .accessibilityLabel("Dragons")
                .position(x: proxy.size.width * 0.38, y: y)

            Button(action: {}) { Rectangle().fill(Color.white.opacity(0.001)) }
                .accessibilityLabel("Quests")
                .position(x: proxy.size.width * 0.61, y: y)

            Button(action: {}) { Rectangle().fill(Color.white.opacity(0.001)) }
                .accessibilityLabel("Profile")
                .position(x: proxy.size.width * 0.84, y: y)
        }
        .buttonStyle(.plain)
        .frame(width: width, height: height)
        .contentShape(Rectangle())
    }
}

#Preview {
    HomeView(onStartSpeaking: {})
}

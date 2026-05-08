import SwiftUI

enum AppRoute {
    case home
    case speak
}

struct AppRootView: View {
    @State private var route: AppRoute = .home

    var body: some View {
        ZStack {
            switch route {
            case .home:
                HomeView(
                    onStartSpeaking: {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                            route = .speak
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 1.02)))

            case .speak:
                SpeakView(
                    onBack: {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.9)) {
                            route = .home
                        }
                    }
                )
                .transition(.opacity)
            }
        }
        .background(Color(red: 0.51, green: 0.81, blue: 0.97))
        .preferredColorScheme(.light)
    }
}

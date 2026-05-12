import SwiftUI

struct AppRootView: View {
    var body: some View {
        TabView {
            VideoLearningView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            MeView()
                .tabItem {
                    Label("Me", systemImage: "person.crop.circle.fill")
                }
        }
        .tint(Color(red: 0.13, green: 0.53, blue: 0.45))
        .preferredColorScheme(.light)
    }
}

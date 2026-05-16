import SwiftUI

struct AppRootView: View {
    @StateObject private var sharedImportStore = SharedImportStore()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            VideoLearningView(sharedImportStore: sharedImportStore)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            KnowledgeView()
                .tabItem {
                    Label("Knowledge", systemImage: "circle.hexagongrid.fill")
                }
                .tag(1)

            MeView()
                .tabItem {
                    Label("Me", systemImage: "person.crop.circle.fill")
                }
                .tag(2)
        }
        .tint(Color(red: 0.13, green: 0.53, blue: 0.45))
        .preferredColorScheme(.light)
        .onOpenURL { url in
            guard url.scheme == SharedImportStore.importURLScheme else { return }
            selectedTab = 0
            sharedImportStore.reload()
        }
        .onAppear {
            sharedImportStore.reload()
        }
    }
}

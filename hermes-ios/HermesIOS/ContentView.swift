import SwiftUI

struct ContentView: View {
    @State private var selectedTab: HermesTab = .chat

    var body: some View {
        TabView(selection: $selectedTab) {
            ChatView(mode: .chat)
                .tabItem { Label("Chat", systemImage: "message") }
                .tag(HermesTab.chat)

            ChatView(mode: .responses)
                .tabItem { Label("Responses", systemImage: "bubble.left.and.bubble.right") }
                .tag(HermesTab.responses)

            ChatView(mode: .runs)
                .tabItem { Label("Runs", systemImage: "bolt.horizontal") }
                .tag(HermesTab.runs)

            JobsView()
                .tabItem { Label("Jobs", systemImage: "calendar.badge.clock") }
                .tag(HermesTab.jobs)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(HermesTab.settings)
        }
    }
}

enum HermesTab {
    case chat
    case responses
    case runs
    case jobs
    case settings
}

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: HermesTab = .chat

    var body: some View {
        TabView(selection: $selectedTab) {
            ChatView(mode: .chat)
                .tabItem { Label("实时", systemImage: "message") }
                .tag(HermesTab.chat)

            ChatView(mode: .responses)
                .tabItem { Label("会话", systemImage: "bubble.left.and.bubble.right") }
                .tag(HermesTab.responses)

            ChatView(mode: .runs)
                .tabItem { Label("Runs", systemImage: "bolt.horizontal") }
                .tag(HermesTab.runs)

            JobsView()
                .tabItem { Label("任务", systemImage: "calendar.badge.clock") }
                .tag(HermesTab.jobs)

            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
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

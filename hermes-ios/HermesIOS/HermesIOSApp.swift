import SwiftUI

@main
struct HermesIOSApp: App {
    @StateObject private var settings = HermesSettings()
    @StateObject private var chatStore = ChatStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(chatStore)
        }
    }
}

import Foundation
import SwiftUI

@MainActor
final class HermesSettings: ObservableObject {
    @AppStorage("baseURL") var baseURL = "http://YOUR_HERMES_HOST:8642/v1"
    @AppStorage("model") var model = "hermes-agent"
    @AppStorage("instructions") var instructions = ""
    @AppStorage("maxTokens") var maxTokens = ""
    @AppStorage("streamResponses") var streamResponses = true

    @Published var apiKey: String = KeychainStore.read(service: "HermesIOS", account: "apiKey") ?? ""

    func saveAPIKey() {
        KeychainStore.save(apiKey, service: "HermesIOS", account: "apiKey")
    }
}

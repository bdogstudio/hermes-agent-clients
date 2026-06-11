import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: HermesSettings
    @State private var status = "Not checked yet"
    @State private var isChecking = false
    @State private var responseID = ""
    @State private var responsePreview = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    TextField("Base URL", text: $settings.baseURL)
                    SecureField("API_SERVER_KEY", text: $settings.apiKey)
                        .onChange(of: settings.apiKey) { _, _ in settings.saveAPIKey() }
                    TextField("Model", text: $settings.model)
                    Button {
                        Task { await checkConnection() }
                    } label: {
                        if isChecking {
                            ProgressView()
                        } else {
                            Label("Check Connection", systemImage: "checkmark.seal")
                        }
                    }
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Chat Configuration") {
                    TextField("max_tokens (optional)", text: $settings.maxTokens)
                    Toggle("Stream Responses output", isOn: $settings.streamResponses)
                    TextEditor(text: $settings.instructions)
                        .frame(minHeight: 100)
                        .overlay(alignment: .topLeading) {
                            if settings.instructions.isEmpty {
                                Text("System prompt (optional)")
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                        }
                }

                Section("Response Records") {
                    TextField("resp_xxx", text: $responseID)
                    HStack {
                        Button("Get Response") {
                            Task { await getResponse() }
                        }
                        Spacer()
                        Button("Delete Response", role: .destructive) {
                            Task { await deleteResponse() }
                        }
                    }
                    if !responsePreview.isEmpty {
                        Text(responsePreview)
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Operation Failed", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func checkConnection() async {
        isChecking = true
        defer { isChecking = false }
        do {
            let client = HermesClient(settings: settings)
            let health = try await client.health()
            let detailed = try? await client.detailedHealth()
            let models = try? await client.models()
            let modelText = models?.data.map(\.id).joined(separator: ", ") ?? "Unknown model"
            let platformText = detailed?.platforms?
                .map { "\($0.key):\($0.value.state ?? "unknown")" }
                .joined(separator: " ") ?? ""
            status = "Connected: \(health.status) · \(modelText)\(platformText.isEmpty ? "" : " · \(platformText)")"
        } catch {
            status = "Connection failed"
            errorMessage = error.localizedDescription
        }
    }

    private func getResponse() async {
        guard !responseID.isEmpty else { return }
        do {
            let result = try await HermesClient(settings: settings).getResponse(id: responseID)
            responsePreview = result.displayText.isEmpty ? "Loaded, but no text content." : result.displayText
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteResponse() async {
        guard !responseID.isEmpty else { return }
        do {
            try await HermesClient(settings: settings).deleteResponse(id: responseID)
            responsePreview = "Deleted: \(responseID)"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

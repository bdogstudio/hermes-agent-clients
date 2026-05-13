import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: HermesSettings
    @State private var status = "尚未检查"
    @State private var isChecking = false
    @State private var responseID = ""
    @State private var responsePreview = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("连接") {
                    TextField("Base URL", text: $settings.baseURL)
                    SecureField("API_SERVER_KEY", text: $settings.apiKey)
                        .onChange(of: settings.apiKey) { _, _ in settings.saveAPIKey() }
                    TextField("模型", text: $settings.model)
                    Button {
                        Task { await checkConnection() }
                    } label: {
                        if isChecking {
                            ProgressView()
                        } else {
                            Label("检查连接", systemImage: "checkmark.seal")
                        }
                    }
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("对话配置") {
                    TextField("max_tokens，可选", text: $settings.maxTokens)
                    Toggle("Responses 使用流式输出", isOn: $settings.streamResponses)
                    TextEditor(text: $settings.instructions)
                        .frame(minHeight: 100)
                        .overlay(alignment: .topLeading) {
                            if settings.instructions.isEmpty {
                                Text("系统提示，可选")
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                        }
                }

                Section("响应记录") {
                    TextField("resp_xxx", text: $responseID)
                    HStack {
                        Button("读取响应") {
                            Task { await getResponse() }
                        }
                        Spacer()
                        Button("删除响应", role: .destructive) {
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
            .navigationTitle("设置")
            .alert("操作失败", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
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
            let modelText = models?.data.map(\.id).joined(separator: ", ") ?? "未知模型"
            let platformText = detailed?.platforms?
                .map { "\($0.key):\($0.value.state ?? "unknown")" }
                .joined(separator: " ") ?? ""
            status = "已连接：\(health.status) · \(modelText)\(platformText.isEmpty ? "" : " · \(platformText)")"
        } catch {
            status = "连接失败"
            errorMessage = error.localizedDescription
        }
    }

    private func getResponse() async {
        guard !responseID.isEmpty else { return }
        do {
            let result = try await HermesClient(settings: settings).getResponse(id: responseID)
            responsePreview = result.displayText.isEmpty ? "已读取，但没有文本内容。" : result.displayText
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteResponse() async {
        guard !responseID.isEmpty else { return }
        do {
            try await HermesClient(settings: settings).deleteResponse(id: responseID)
            responsePreview = "已删除：\(responseID)"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

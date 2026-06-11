import SwiftUI

struct ChatView: View {
    let mode: ChatMode

    @EnvironmentObject private var settings: HermesSettings
    @EnvironmentObject private var store: ChatStore
    @State private var draft = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(store.messages(for: mode)) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }

                            if store.messages(for: mode).isEmpty {
                                ContentUnavailableView(mode.title, systemImage: "message", description: Text("Send Hermes a message."))
                                    .padding(.top, 80)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: store.messages(for: mode)) { _, messages in
                        guard let last = messages.last else { return }
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }

                if !store.events(for: mode).isEmpty {
                    DisclosureGroup("Status / Tool Progress") {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(store.events(for: mode)) { event in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(event.title).font(.caption.bold())
                                        Text(event.detail).font(.caption).foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            .padding(.top, 8)
                        }
                        .frame(maxHeight: 150)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }

                composer
            }
            .navigationTitle(mode.title)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("New") {
                        store.reset(mode: mode)
                    }
                }
                ToolbarItem(placement: .automatic) {
                    if isSending {
                        ProgressView()
                    }
                }
            }
            .alert("Request Failed", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 8) {
            TextEditor(text: $draft)
                .frame(minHeight: 44, maxHeight: 120)
                .padding(6)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

            HStack {
                Text("Type to add a line, tap Send to submit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    Task { await send() }
                } label: {
                    Label("Send", systemImage: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
        }
        .padding()
        .background(.background)
    }

    private func send() async {
        let input = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        draft = ""
        isSending = true
        errorMessage = nil

        let client = HermesClient(settings: settings)
        store.append(ChatMessage(role: .user, text: input), to: mode)
        store.append(ChatMessage(role: .assistant, text: ""), to: mode)
        store.clearEvents(for: mode)

        do {
            switch mode {
            case .chat:
                try await client.streamChat(messages: store.messages(for: mode).dropLast().map { $0 }, sessionID: store.hermesSessionID(for: mode)) { event in
                    handle(event)
                }
            case .responses:
                if settings.streamResponses {
                    try await client.streamResponse(input: input, previousResponseID: store.previousResponseID(for: mode)) { event in
                        handle(event)
                    }
                } else {
                    let result = try await client.sendResponse(input: input, previousResponseID: store.previousResponseID(for: mode))
                    store.replaceLastAssistant(result.displayText, meta: result.id, in: mode)
                    store.setPreviousResponseID(result.id, for: mode)
                    for output in result.output ?? [] {
                        store.addEvent(output.type, detail: output.name ?? output.output ?? "", to: mode)
                    }
                }
            case .runs:
                try await client.streamRun(input: input) { event in
                    handle(event)
                }
            }
        } catch {
            store.replaceLastAssistant("Connection or execution failed: \(error.localizedDescription)", in: mode)
            errorMessage = error.localizedDescription
        }

        isSending = false
    }

    @MainActor
    private func handle(_ event: HermesStreamEvent) {
        switch event {
        case .text(let text):
            store.appendAssistantDelta(text, to: mode)
        case .progress(let title, let detail):
            store.addEvent(title, detail: detail, to: mode)
        case .responseID(let id):
            store.setPreviousResponseID(id, for: mode)
        case .session(let id):
            store.setHermesSessionID(id, for: mode)
        case .done:
            break
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 4) {
                Text(message.text.isEmpty ? "..." : message.text)
                    .textSelection(.enabled)
                if let meta = message.meta, !meta.isEmpty {
                    Text(meta)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .foregroundStyle(message.role == .user ? .white : .primary)
            .background(message.role == .user ? Color.accentColor : Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            if message.role != .user { Spacer(minLength: 40) }
        }
    }
}

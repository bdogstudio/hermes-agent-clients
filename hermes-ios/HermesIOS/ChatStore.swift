import Foundation

@MainActor
final class ChatStore: ObservableObject {
    @Published private var states: [ChatMode: ChatStoreState] = [
        .chat: ChatStoreState(),
        .responses: ChatStoreState(),
        .runs: ChatStoreState()
    ]

    func state(for mode: ChatMode) -> ChatStoreState {
        states[mode] ?? ChatStoreState()
    }

    func messages(for mode: ChatMode) -> [ChatMessage] {
        state(for: mode).messages
    }

    func events(for mode: ChatMode) -> [HermesEvent] {
        state(for: mode).events
    }

    func append(_ message: ChatMessage, to mode: ChatMode) {
        states[mode, default: ChatStoreState()].messages.append(message)
    }

    func appendAssistantDelta(_ delta: String, to mode: ChatMode) {
        guard !delta.isEmpty else { return }
        if let index = states[mode, default: ChatStoreState()].messages.lastIndex(where: { $0.role == .assistant }) {
            states[mode, default: ChatStoreState()].messages[index].text += delta
        } else {
            append(ChatMessage(role: .assistant, text: delta), to: mode)
        }
    }

    func replaceLastAssistant(_ text: String, meta: String? = nil, in mode: ChatMode) {
        if let index = states[mode, default: ChatStoreState()].messages.lastIndex(where: { $0.role == .assistant }) {
            states[mode, default: ChatStoreState()].messages[index].text = text
            states[mode, default: ChatStoreState()].messages[index].meta = meta
        } else {
            append(ChatMessage(role: .assistant, text: text, meta: meta), to: mode)
        }
    }

    func addEvent(_ title: String, detail: String, to mode: ChatMode) {
        states[mode, default: ChatStoreState()].events.append(HermesEvent(title: title, detail: detail))
    }

    func clearEvents(for mode: ChatMode) {
        states[mode, default: ChatStoreState()].events.removeAll()
    }

    func previousResponseID(for mode: ChatMode) -> String? {
        states[mode]?.previousResponseID
    }

    func setPreviousResponseID(_ id: String?, for mode: ChatMode) {
        states[mode, default: ChatStoreState()].previousResponseID = id
    }

    func hermesSessionID(for mode: ChatMode) -> String? {
        states[mode]?.hermesSessionID
    }

    func setHermesSessionID(_ id: String?, for mode: ChatMode) {
        states[mode, default: ChatStoreState()].hermesSessionID = id
    }

    func reset(mode: ChatMode) {
        states[mode] = ChatStoreState()
    }
}

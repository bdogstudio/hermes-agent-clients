import Foundation

enum ChatMode: String {
    case chat
    case responses
    case runs

    var title: String {
        switch self {
        case .chat: "实时消息"
        case .responses: "会话保持"
        case .runs: "Runs"
        }
    }
}

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: Role
    var text: String
    var meta: String?

    init(id: UUID = UUID(), role: Role, text: String, meta: String? = nil) {
        self.id = id
        self.role = role
        self.text = text
        self.meta = meta
    }

    enum Role {
        case user
        case assistant
        case system
    }
}

struct ChatStoreState {
    var messages: [ChatMessage] = []
    var previousResponseID: String?
    var hermesSessionID: String?
    var events: [HermesEvent] = []
}

struct HermesEvent: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let detail: String
}

struct HermesModelList: Decodable {
    let data: [HermesModel]
}

struct HermesModel: Decodable, Identifiable {
    let id: String
    let ownedBy: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownedBy = "owned_by"
    }
}

struct HealthResponse: Decodable {
    let status: String
    let platform: String?
}

struct DetailedHealthResponse: Decodable {
    let status: String
    let platform: String?
    let gatewayState: String?
    let activeAgents: Int?
    let pid: Int?
    let platforms: [String: PlatformHealth]?

    enum CodingKeys: String, CodingKey {
        case status
        case platform
        case gatewayState = "gateway_state"
        case activeAgents = "active_agents"
        case platforms
        case pid
    }
}

struct PlatformHealth: Decodable {
    let state: String?
}

struct ResponseResult: Decodable {
    let id: String?
    let status: String?
    let output: [ResponseOutput]?
    let usage: Usage?
}

struct ResponseOutput: Decodable, Identifiable {
    var id: String { callID ?? name ?? type }
    let type: String
    let role: String?
    let name: String?
    let arguments: String?
    let callID: String?
    let output: String?
    let content: [ResponseContent]?

    enum CodingKeys: String, CodingKey {
        case type
        case role
        case name
        case arguments
        case callID = "call_id"
        case output
        case content
    }
}

struct ResponseContent: Decodable {
    let type: String?
    let text: String?
}

struct Usage: Decodable {
    let promptTokens: Int?
    let completionTokens: Int?
    let inputTokens: Int?
    let outputTokens: Int?
    let totalTokens: Int?

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case totalTokens = "total_tokens"
    }
}

struct JobList: Decodable {
    let jobs: [HermesJob]
}

struct HermesJob: Decodable, Identifiable {
    let id: String
    let name: String?
    let prompt: String?
    let scheduleDisplay: String?
    let enabled: Bool?
    let state: String?
    let nextRunAt: String?
    let lastStatus: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case prompt
        case scheduleDisplay = "schedule_display"
        case enabled
        case state
        case nextRunAt = "next_run_at"
        case lastStatus = "last_status"
    }
}

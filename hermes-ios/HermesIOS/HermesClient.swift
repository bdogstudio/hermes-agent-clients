import Foundation

actor HermesClient {
    private let settings: HermesSettings

    init(settings: HermesSettings) {
        self.settings = settings
    }

    private var baseURL: String {
        get async { await MainActor.run { settings.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) } }
    }

    private var apiKey: String {
        get async { await MainActor.run { settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines) } }
    }

    private var model: String {
        get async { await MainActor.run { settings.model.isEmpty ? "hermes-agent" : settings.model } }
    }

    private var instructions: String {
        get async { await MainActor.run { settings.instructions.trimmingCharacters(in: .whitespacesAndNewlines) } }
    }

    private var maxTokens: Int? {
        get async {
            await MainActor.run {
                Int(settings.maxTokens.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
    }

    private func url(_ endpoint: String) async throws -> URL {
        let base = await baseURL
        let full: String

        if endpoint.hasPrefix("/health") || endpoint.hasPrefix("/api/") {
            full = base.hasSuffix("/v1") ? String(base.dropLast(3)) + endpoint : base + endpoint
        } else if base.hasSuffix("/v1"), endpoint.hasPrefix("/v1/") {
            full = base + String(endpoint.dropFirst(3))
        } else if !base.hasSuffix("/v1"), !endpoint.hasPrefix("/v1/") {
            full = base + "/v1" + endpoint
        } else {
            full = base + endpoint
        }

        guard let url = URL(string: full) else {
            throw HermesError.invalidURL(full)
        }
        return url
    }

    private func request(_ endpoint: String, method: String = "GET", body: Data? = nil, headers: [String: String] = [:]) async throws -> URLRequest {
        var request = URLRequest(url: try await url(endpoint))
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let key = await apiKey
        if !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }

    private func decode<T: Decodable>(_ type: T.Type, from request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(type, from: data)
    }

    private func rawJSON(from request: URLRequest) async throws -> Any {
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONSerialization.jsonObject(with: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw HermesError.http(http.statusCode, message)
        }
    }

    func health() async throws -> HealthResponse {
        try await decode(HealthResponse.self, from: try await request("/health"))
    }

    func detailedHealth() async throws -> DetailedHealthResponse {
        try await decode(DetailedHealthResponse.self, from: try await request("/health/detailed"))
    }

    func models() async throws -> HermesModelList {
        try await decode(HermesModelList.self, from: try await request("/v1/models"))
    }

    func sendResponse(input: String, previousResponseID: String?) async throws -> ResponseResult {
        var payload: [String: Any] = [
            "model": await model,
            "input": input,
            "store": true,
            "stream": false
        ]
        payload["previous_response_id"] = previousResponseID ?? NSNull()
        let instructions = await instructions
        if !instructions.isEmpty { payload["instructions"] = instructions }
        if let maxTokens = await maxTokens { payload["max_tokens"] = maxTokens }
        let data = try JSONSerialization.data(withJSONObject: payload)
        return try await decode(ResponseResult.self, from: try await request("/v1/responses", method: "POST", body: data))
    }

    func getResponse(id: String) async throws -> ResponseResult {
        try await decode(ResponseResult.self, from: try await request("/v1/responses/\(id)"))
    }

    func deleteResponse(id: String) async throws {
        _ = try await rawJSON(from: try await request("/v1/responses/\(id)", method: "DELETE"))
    }

    func jobs() async throws -> [HermesJob] {
        try await decode(JobList.self, from: try await request("/api/jobs")).jobs
    }

    func createJob(name: String, schedule: String, prompt: String) async throws {
        let payload: [String: Any] = ["name": name, "schedule": schedule, "prompt": prompt]
        let data = try JSONSerialization.data(withJSONObject: payload)
        _ = try await rawJSON(from: try await request("/api/jobs", method: "POST", body: data))
    }

    func jobAction(id: String, action: String) async throws {
        let endpoint = action == "delete" ? "/api/jobs/\(id)" : "/api/jobs/\(id)/\(action)"
        let method = action == "delete" ? "DELETE" : "POST"
        _ = try await rawJSON(from: try await request(endpoint, method: method))
    }

    func streamChat(messages: [ChatMessage], sessionID: String?, onEvent: @escaping @MainActor (HermesStreamEvent) -> Void) async throws {
        var apiMessages: [[String: String]] = []
        let instructions = await instructions
        if !instructions.isEmpty {
            apiMessages.append(["role": "system", "content": instructions])
        }
        apiMessages.append(contentsOf: messages.compactMap { message in
            switch message.role {
            case .user: ["role": "user", "content": message.text]
            case .assistant: ["role": "assistant", "content": message.text]
            case .system: ["role": "system", "content": message.text]
            }
        })

        var payload: [String: Any] = [
            "model": await model,
            "messages": apiMessages,
            "stream": true
        ]
        if let maxTokens = await maxTokens { payload["max_tokens"] = maxTokens }
        let data = try JSONSerialization.data(withJSONObject: payload)
        var headers: [String: String] = ["Idempotency-Key": UUID().uuidString]
        if let sessionID, !sessionID.isEmpty {
            headers["X-Hermes-Session-Id"] = sessionID
        }
        let request = try await request("/v1/chat/completions", method: "POST", body: data, headers: headers)
        try await stream(request: request, onEvent: onEvent)
    }

    func streamResponse(input: String, previousResponseID: String?, onEvent: @escaping @MainActor (HermesStreamEvent) -> Void) async throws {
        var payload: [String: Any] = [
            "model": await model,
            "input": input,
            "store": true,
            "stream": true
        ]
        payload["previous_response_id"] = previousResponseID ?? NSNull()
        let instructions = await instructions
        if !instructions.isEmpty { payload["instructions"] = instructions }
        if let maxTokens = await maxTokens { payload["max_tokens"] = maxTokens }
        let data = try JSONSerialization.data(withJSONObject: payload)
        let request = try await request("/v1/responses", method: "POST", body: data)
        try await stream(request: request, onEvent: onEvent)
    }

    func streamRun(input: String, onEvent: @escaping @MainActor (HermesStreamEvent) -> Void) async throws {
        var payload: [String: Any] = ["model": await model, "input": input]
        let instructions = await instructions
        if !instructions.isEmpty { payload["instructions"] = instructions }
        let data = try JSONSerialization.data(withJSONObject: payload)
        let created = try await rawJSON(from: try await request("/v1/runs", method: "POST", body: data))
        guard
            let dict = created as? [String: Any],
            let runID = dict["id"] as? String ?? dict["run_id"] as? String
        else {
            throw HermesError.decoding("Runs endpoint did not return an id")
        }
        await MainActor.run {
            onEvent(.progress(title: "run.created", detail: runID))
        }
        let request = try await request("/v1/runs/\(runID)/events", headers: ["Accept": "text/event-stream"])
        try await stream(request: request, onEvent: onEvent)
    }

    private func stream(request: URLRequest, onEvent: @escaping @MainActor (HermesStreamEvent) -> Void) async throws {
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        if let http = response as? HTTPURLResponse, let sessionID = http.value(forHTTPHeaderField: "X-Hermes-Session-Id") {
            await MainActor.run { onEvent(.session(sessionID)) }
        }

        var eventName = "message"
        var dataLines: [String] = []

        for try await line in bytes.lines {
            if line.isEmpty {
                await emitSSE(eventName: eventName, data: dataLines.joined(separator: "\n"), onEvent: onEvent)
                eventName = "message"
                dataLines = []
            } else if line.hasPrefix("event:") {
                eventName = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
            }
        }

        if !dataLines.isEmpty {
            await emitSSE(eventName: eventName, data: dataLines.joined(separator: "\n"), onEvent: onEvent)
        }
    }

    @MainActor
    private func emitSSE(eventName: String, data: String, onEvent: @escaping @MainActor (HermesStreamEvent) -> Void) {
        guard !data.isEmpty else { return }
        if data == "[DONE]" {
            onEvent(.done)
            return
        }

        guard let jsonData = data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData),
              let object = json as? [String: Any]
        else {
            onEvent(.text(data))
            return
        }

        if eventName != "message" {
            onEvent(.progress(title: eventName, detail: data))
        }

        if let responseID = object["id"] as? String,
           (object["object"] as? String == "response" || responseID.hasPrefix("resp_")) {
            onEvent(.responseID(responseID))
        }

        if let choices = object["choices"] as? [[String: Any]],
           let delta = choices.first?["delta"] as? [String: Any],
           let content = delta["content"] as? String {
            onEvent(.text(content))
            return
        }

        if let delta = object["delta"] as? String {
            onEvent(.text(delta))
        } else if let text = object["text"] as? String {
            onEvent(.text(text))
        }
    }
}

enum HermesStreamEvent {
    case text(String)
    case progress(title: String, detail: String)
    case responseID(String)
    case session(String)
    case done
}

enum HermesError: LocalizedError {
    case invalidURL(String)
    case http(Int, String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url): "Invalid URL: \(url)"
        case .http(let code, let message): "HTTP \(code): \(message)"
        case .decoding(let message): message
        }
    }
}

extension ResponseResult {
    var displayText: String {
        output?
            .flatMap { $0.content ?? [] }
            .compactMap(\.text)
            .joined()
        ?? ""
    }
}

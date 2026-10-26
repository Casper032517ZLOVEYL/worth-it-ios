import Foundation
import Observation

struct TreeMessage: Identifiable, Codable {
    var id = UUID()
    let role: String
    let content: String
    var date = Date()
}

@Observable @MainActor final class TreeHoleStore {
    private struct Archive: Codable {
        var messages: [TreeMessage]
        var consent: String?
        var draft: String
    }
    private(set) var messages: [TreeMessage] = []
    var draft = ""
    var error: String?
    private(set) var sending = false
    private(set) var checking = false
    private(set) var available = false
    private(set) var provider = ""
    private(set) var privacyURL: URL?
    private var consent: String?
    private let canSave: () -> Bool
    private let defaults: UserDefaults
    private let key: String
    private var token: String?
    private var task: Task<Void, Never>?
    private var revision = UUID()
    private let baseURL: URL?
    var configured: Bool { baseURL != nil }
    private var consentID: String { "\(baseURL?.absoluteString ?? "")|\(provider)|\(privacyURL?.absoluteString ?? "")|v1" }
    var consented: Bool { available && consent == consentID }
    var hasPending: Bool { messages.last?.role == "user" }

    init(profileID: UUID, defaults: UserDefaults, canSave: @escaping () -> Bool = { true }) {
        self.canSave = canSave
        self.defaults = defaults
        key = "worthit.tree-hole.v1.\(profileID.uuidString)"
        let raw = (Bundle.main.object(forInfoDictionaryKey: "TreeHoleBaseURL") as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: raw), url.scheme == "https", url.host != nil, url.user == nil, url.password == nil, url.query == nil, url.fragment == nil { baseURL = url }
        else { baseURL = nil }
        if let data = defaults.data(forKey: key), let archive = try? JSONDecoder().decode(Archive.self, from: data) {
            messages = archive.messages; consent = archive.consent; draft = archive.draft
        }
    }
    func save() {
        guard canSave() else { return }
        if let data = try? JSONEncoder().encode(Archive(messages: messages, consent: consent, draft: draft)) { defaults.set(data, forKey: key) }
    }
    func approve() { consent = consentID; save() }
    func revoke() { cancel(); consent = nil; token = nil; save() }
    func clear() { cancel(); messages = []; draft = ""; error = nil; save() }
    func cancel() { revision = UUID(); task?.cancel(); task = nil; sending = false }
    func refresh() async {
        guard configured else { return }
        checking = true
        defer { checking = false }
        do {
            struct Status: Decodable { let available: Bool; let providerName: String; let privacyURL: String? }
            let status: Status = try await request("tree-hole/status", method: "GET")
            provider = status.providerName
            privacyURL = status.privacyURL.flatMap(URL.init(string:)).flatMap { $0.scheme == "https" ? $0 : nil }
            available = status.available && privacyURL != nil
            error = nil
        } catch is CancellationError {} catch { self.error = error.localizedDescription; available = false }
    }
    func send(retry: Bool = false) {
        guard available, consented, !sending else { return }
        if !retry {
            let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty, content.count <= 3000, !hasPending else { return }
            messages.append(TreeMessage(role: "user", content: content)); draft = ""
            // Keep full pairs, with a bounded local archive of the latest 100 messages.
            if messages.count > 100 { messages.removeFirst(2) }
        }
        guard hasPending else { return }
        error = nil; sending = true; save()
        let current = UUID(); revision = current
        task = Task { [weak self] in
            guard let self else { return }
            defer { if self.revision == current { self.sending = false; self.task = nil } }
            do {
                for attempt in 0..<2 {
                    try Task.checkCancellation()
                    if self.token == nil {
                        struct Session: Decodable { let token: String }
                        let result: Session = try await self.request("tree-hole/session", body: [:])
                        try Task.checkCancellation()
                        self.token = result.token
                    }
                    do {
                        var context = Array(self.messages.suffix(21))
                        while context.first?.role == "assistant" { context.removeFirst() }
                        while context.reduce(0, { $0 + $1.content.count }) > 16000 && context.count > 1 { context.removeFirst(2) }
                        struct Reply: Decodable { let reply: String }
                        let result: Reply = try await self.request("tree-hole/messages", body: ["consent": true, "messages": context.map { ["role": $0.role, "content": $0.content] }], token: self.token)
                        try Task.checkCancellation()
                        guard self.revision == current else { return }
                        self.messages.append(TreeMessage(role: "assistant", content: result.reply)); self.save()
                        break
                    } catch let failure as ChatFailure where failure.status == 401 && attempt == 0 { self.token = nil }
                }
            } catch {
                if self.revision == current && !Task.isCancelled { self.error = error.localizedDescription }
            }
        }
    }
    private struct Failure: Decodable { let error: String }
    private struct ChatFailure: LocalizedError {
        let status: Int
        let message: String
        var errorDescription: String? { message }
    }
    private func request<T: Decodable>(_ path: String, method: String = "POST", body: [String: Any]? = nil, token: String? = nil) async throws -> T {
        guard let baseURL else { throw ChatFailure(status: 503, message: "树洞聊天服务尚未配置。") }
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method; request.timeoutInterval = 50
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, response) = try await URLSession.shared.data(for: request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else { throw ChatFailure(status: 502, message: "暂时无法连接树洞。") }
        guard (200..<300).contains(response.statusCode) else {
            let detail = (try? JSONDecoder().decode(Failure.self, from: data))?.error
            throw ChatFailure(status: response.statusCode, message: detail ?? "暂时没有收到回复，请稍后重试。")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

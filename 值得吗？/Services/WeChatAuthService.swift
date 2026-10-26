import Foundation
import UIKit
import Observation
import Security
@preconcurrency import WechatOpenSDK

struct WeChatConfiguration {
    let appID: String
    let universalLink: String
    let backend: URL?
    init(bundle: Bundle = .main) {
        appID = bundle.object(forInfoDictionaryKey: "WeChatAppID") as? String ?? ""
        universalLink = bundle.object(forInfoDictionaryKey: "WeChatUniversalLink") as? String ?? ""
        let general = bundle.object(forInfoDictionaryKey: "AuthBaseURL") as? String ?? ""
        let legacy = bundle.object(forInfoDictionaryKey: "WeChatAuthBaseURL") as? String ?? ""
        backend = URL(string: general.isEmpty ? legacy : general)
    }
    var hasBackend: Bool { backend?.scheme == "https" && backend?.host != nil }
    var isConfigured: Bool {
        appID.range(of: "^wx[a-zA-Z0-9]{16}$", options: .regularExpression) != nil &&
        URL(string: universalLink)?.scheme == "https" && URL(string: universalLink)?.host != nil &&
        universalLink.hasSuffix("/") && backend?.scheme == "https" && backend?.host != nil
    }
    var status: String {
        isConfigured ? "已配置微信授权参数，需在安装微信的真机上验证。" : "微信授权待配置：AppID、Universal Link 和 HTTPS 服务端地址。"
    }
}

private struct WeChatCredential: Codable {
    let sessionToken: String
    let expiresAt: Date
    let user: WeChatUser
}

private enum SessionKeychain {
    static let service = "com.casper.WorthIt.wechat-session"
    static var query: [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "active"] }
    static func save(_ value: WeChatCredential) throws {
        let data = try JSONEncoder().encode(value)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw WeChatError.message("登录凭证无法安全保存，请重试。") }
        } else if status != errSecSuccess { throw WeChatError.message("登录凭证无法安全保存，请重试。") }
    }
    static func load() -> WeChatCredential? {
        var item = query
        item[kSecReturnData as String] = true
        item[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(item as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(WeChatCredential.self, from: data)
    }
    static func clear() { SecItemDelete(query as CFDictionary) }
}

enum WeChatError: LocalizedError {
    case message(String)
    var errorDescription: String? { switch self { case .message(let text): text } }
}

@MainActor @Observable final class WeChatAuthService: NSObject, WXApiDelegate {
    static let shared = WeChatAuthService()
    let configuration = WeChatConfiguration()
    private(set) var isBusy = false
    private(set) var authenticatedUser: WeChatUser?
    var errorMessage: String?
    private var bindingWeChat = false
    private var registered = false
    private var flowID = UUID()
    private var pending: Challenge?
    private var timeoutTask: Task<Void, Never>?
    private let session = URLSession(configuration: .ephemeral)
    private struct Challenge: Decodable {
        let challengeID: String
        let state: String
        let expiresAt: Date
    }
    var canOfferLogin: Bool { configuration.isConfigured && WXApi.isWXAppInstalled() }

    func configureIfPreviouslyConsented() {
        if UserDefaults.standard.bool(forKey: "worthit.wechat.consent") { registerSDK() }
    }
    private func registerSDK() {
        guard configuration.isConfigured, !registered else { return }
        registered = WXApi.registerApp(configuration.appID, universalLink: configuration.universalLink)
    }

    func beginLogin(forBinding: Bool = false) async {
        guard !isBusy else { return }
        guard configuration.isConfigured else { errorMessage = configuration.status; return }
        guard WXApi.isWXAppInstalled() else { errorMessage = "请在安装微信的 iPhone 上使用微信授权。"; return }
        UserDefaults.standard.set(true, forKey: "worthit.wechat.consent")
        registerSDK()
        guard registered else { errorMessage = "微信 SDK 注册失败，请检查 AppID 与 Universal Link 配置。"; return }
        isBusy = true
        flowID = UUID()
        let flow = flowID
        bindingWeChat = forBinding
        if !forBinding { authenticatedUser = nil }
        do {
            let challenge: Challenge = try await request("auth/wechat/challenge", body: [:])
            guard flowID == flow, isBusy else { return }
            guard challenge.expiresAt > .now, challenge.state.count >= 32 else { throw WeChatError.message("授权请求无效，请重试。") }
            pending = challenge
            let req = SendAuthReq()
            req.scope = "snsapi_userinfo"
            req.state = challenge.state
            guard await WXApi.send(req) else { fail("未能打开微信授权，请检查微信和应用配置。"); return }
            guard self.pending != nil else { return }
            timeoutTask?.cancel()
            timeoutTask = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(300)) } catch { return }
                self?.fail("本次授权已超时，请重新发起。")
            }
        } catch { fail(error.localizedDescription) }
    }

    func handle(url: URL) -> Bool {
        guard registered, url.scheme == configuration.appID else { return false }
        return WXApi.handleOpen(url, delegate: self)
    }
    func handle(activity: NSUserActivity) -> Bool {
        guard registered, let url = activity.webpageURL,
              url.absoluteString.hasPrefix(configuration.universalLink) else { return false }
        return WXApi.handleOpenUniversalLink(activity, delegate: self)
    }

    func onResp(_ resp: BaseResp) {
        guard let response = resp as? SendAuthResp, let pending else { return }
        guard pending.expiresAt > .now, response.state == pending.state else { fail("授权状态校验失败，请重新登录。"); return }
        if response.errCode == -2 { fail("你已取消微信授权。"); return }
        if response.errCode == -4 { fail("你未同意微信授权，可以使用其他注册方式。"); return }
        guard response.errCode == 0, let code = response.code, !code.isEmpty else { fail("微信授权未完成，请重试。"); return }
        self.pending = nil // Consume once; duplicate callbacks cannot exchange a code twice.
        let flow = flowID
        timeoutTask?.cancel()
        Task {
            do {
                let body = ["code": code, "state": pending.state, "challengeID": pending.challengeID]
                if bindingWeChat {
                    let user: WeChatUser = try await authenticatedRequest("account/bind/wechat", body: body)
                    guard flowID == flow, isBusy else { return }
                    try updateSession(user); isBusy = false; return
                }
                let credential: WeChatCredential = try await request("auth/wechat/exchange", body: body)
                guard flowID == flow, isBusy else { return }
                guard credential.expiresAt > .now, !credential.sessionToken.isEmpty, !credential.user.id.isEmpty else { throw WeChatError.message("服务端返回的登录信息无效。") }
                try SessionKeychain.save(credential)
                authenticatedUser = credential.user
                isBusy = false
            } catch { fail(error.localizedDescription) }
        }
    }

    func restoreSession() async throws -> WeChatUser? {
        if let authenticatedUser { return authenticatedUser }
        guard configuration.hasBackend, let saved = SessionKeychain.load(), saved.expiresAt > .now else { return nil }
        do {
            let user: WeChatUser = try await request("auth/session", token: saved.sessionToken)
            authenticatedUser = user
            return user
        } catch {
            // A transient network failure must not grant access to a verified profile.
            throw error
        }
    }
    func signOut() {
        let saved = SessionKeychain.load()
        SessionKeychain.clear()
        authenticatedUser = nil
        flowID = UUID()
        pending = nil
        timeoutTask?.cancel()
        isBusy = false
        if let saved, configuration.hasBackend {
            Task { let _: WeChatUser? = try? await request("auth/logout", token: saved.sessionToken, body: [:]) }
        }
    }
    struct VerificationChallenge: Decodable {
        let challengeID: String
        let expiresAt: Date
        let resendAfter: Int
    }
    func sendCode(target: String, purpose: String = "login", channel: String = "sms") async throws -> VerificationChallenge {
        let body = ["target": target, "purpose": purpose, "channel": channel]
        if purpose == "login" { return try await request("auth/verification/send", body: body) }
        return try await authenticatedRequest("auth/verification/send", body: body)
    }
    func verifyPhone(target: String, challenge: String, code: String) async throws -> WeChatUser {
        let credential: WeChatCredential = try await request("auth/phone/verify", body: ["target": target, "challengeID": challenge, "code": code])
        guard credential.expiresAt > .now, !credential.user.id.isEmpty, credential.user.phone == target else {
            throw WeChatError.message("登录信息无效，请重新获取验证码。")
        }
        try SessionKeychain.save(credential)
        authenticatedUser = credential.user
        return credential.user
    }
    func updateAccount(purpose: String, target: String, challenge: String, code: String, password: String = "") async throws {
        let user: WeChatUser = try await authenticatedRequest("account/" + purpose, body: ["target": target, "challengeID": challenge, "code": code, "password": password])
        try updateSession(user)
    }
    func revokeOtherSessions() async throws {
        let user: WeChatUser = try await authenticatedRequest("account/revoke-others", body: [:])
        try updateSession(user)
    }
    func deleteAccount() async throws {
        let _: WeChatUser = try await authenticatedRequest("account/delete", body: [:])
        SessionKeychain.clear(); authenticatedUser = nil
    }
    private func updateSession(_ user: WeChatUser) throws {
        guard let saved = SessionKeychain.load() else { throw WeChatError.message("请重新登录。") }
        try SessionKeychain.save(WeChatCredential(sessionToken: saved.sessionToken, expiresAt: saved.expiresAt, user: user))
        authenticatedUser = user
    }
    private func authenticatedRequest<T: Decodable>(_ path: String, body: [String: String]) async throws -> T {
        guard let saved = SessionKeychain.load(), saved.expiresAt > .now else { throw WeChatError.message("请先通过手机号或微信登录。") }
        return try await request(path, token: saved.sessionToken, body: body)
    }
    private func fail(_ message: String) {
        flowID = UUID()
        pending = nil
        timeoutTask?.cancel()
        isBusy = false
        errorMessage = message
    }
    private func request<T: Decodable>(_ path: String, token: String? = nil, body: [String: String]? = nil) async throws -> T {
        guard let base = configuration.backend, configuration.hasBackend else { throw WeChatError.message("登录服务尚未开放，请稍后再试。") }
        #if DEBUG
        if ProcessInfo.processInfo.environment["WORTHIT_UI_TESTING"] == "1" {
            throw WeChatError.message("界面测试不发送验证码，请在正常运行的 App 中联调。")
        }
        #endif
        var req = URLRequest(url: base.appendingPathComponent(path), cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        req.httpMethod = body == nil ? "GET" : "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { req.httpBody = try JSONEncoder().encode(body); req.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw WeChatError.message("登录服务暂时不可用。") }
        guard (200..<300).contains(http.statusCode) else {
            throw WeChatError.message(http.statusCode == 401 ? "验证码无效、已过期，或登录已失效，请重试。" : http.statusCode == 429 ? "请求过于频繁，请稍后再试。" : http.statusCode == 409 ? "该联系方式已绑定其他账号。" : http.statusCode == 503 ? "验证码服务尚未开放，请稍后再试。" : "登录服务暂时不可用（\(http.statusCode)）。")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}

final class WeChatAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        WeChatAuthService.shared.configureIfPreviouslyConsented()
        return true
    }
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        WeChatAuthService.shared.handle(url: url)
    }
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([any UIUserActivityRestoring]?) -> Void) -> Bool {
        WeChatAuthService.shared.handle(activity: userActivity)
    }
}

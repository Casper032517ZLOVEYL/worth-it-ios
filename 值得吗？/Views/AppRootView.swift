import SwiftUI

struct AppRootView: View {
    @State private var account: AccountStore
    @State private var auth = WeChatAuthService.shared
    @State private var restoreError: String?
    // SwiftUI can recreate the view value. Initialize persistence and the test
    // reset once per process, so a later view update cannot erase saved profiles.
    private static let initialAccount: AccountStore = {
        #if DEBUG
        if ProcessInfo.processInfo.environment["WORTHIT_UI_TESTING"] == "1" {
            let suite = "worthit.ui-tests"
            let defaults = UserDefaults(suiteName: suite)!
            if ProcessInfo.processInfo.environment["WORTHIT_UI_RESET"] == "1" { defaults.removePersistentDomain(forName: suite) }
            let account = AccountStore(defaults: defaults)
            if ProcessInfo.processInfo.environment["WORTHIT_UI_RESET"] == "1" { account.language = .zhHans }
            return account
        } else { return AccountStore() }
        #else
        return AccountStore()
        #endif
    }()
    init() {
        _account = State(initialValue: Self.initialAccount)
    }
    var body: some View {
        Group {
            if let profile = account.activeProfile, profile.isLocalOnly || auth.authenticatedUser?.id == (profile.serverUserID ?? (profile.method == .wechat ? profile.identifier : "unverified")) {
                ContentView(account: account, profile: profile).id(profile.id)
            } else if account.activeProfile != nil {
                VStack(spacing: 22) {
                    ProgressView().tint(OracleTheme.accent)
                    AppText(restoreError ?? "正在确认登录状态…").font(.system(size: 14))
                    if restoreError != nil {
                        Button(L10n.t("重试")) { Task { await restore() } }
                        Button(L10n.t("返回注册界面")) { auth.signOut(); account.signOut() }
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity).background(OracleTheme.background).foregroundStyle(OracleTheme.ink)
            } else {
                RegistrationView(account: account)
            }
        }
        .fontDesign(.rounded)
        .preferredColorScheme(account.appearance.colorScheme)
        .tint(OracleTheme.accent)
        .environment(\.locale, Locale(identifier: account.language.resolvedCode))
        .environment(\.layoutDirection, account.language.isRTL ? .rightToLeft : .leftToRight)
        .onChange(of: auth.authenticatedUser) { _, user in if let user { account.refreshVerifiedIdentity(user) } }
        .task(id: account.activeID) { await restore() }
        .alert(L10n.t("档案提示"), isPresented: Binding(get: { account.error != nil }, set: { if !$0 { account.error = nil } })) {
            Button(L10n.t("知道了")) { account.error = nil }
        } message: { AppText(account.error ?? "") }
    }
    private func restore() async {
        guard let profile = account.activeProfile, !profile.isLocalOnly else { return }
        restoreError = nil
        do {
            guard let user = try await auth.restoreSession(), user.id == (profile.serverUserID ?? (profile.method == .wechat ? profile.identifier : "unverified")) else {
                restoreError = "登录已失效，请重新验证。"; return
            }
        } catch { restoreError = "暂时无法验证登录。请检查网络后重试。" }
    }
}

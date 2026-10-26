import SwiftUI

struct AccountSecurityView: View {
    let account: AccountStore
    let profile: UserProfile
    @State private var auth = WeChatAuthService.shared
    @State private var delete = false
    @State private var busy = false
    @State private var message: String?
    private var user: WeChatUser? { auth.authenticatedUser }
    var body: some View {
        List {
            Section {
                NavigationLink("设置密码") { AccountContactView(purpose: .password) }
            }
            Section {
                NavigationLink { AccountContactView(purpose: .phone) } label: {
                    row("手机号码", value: maskPhone(user?.phone), action: user?.phone == nil ? "绑定" : "更换")
                }
                NavigationLink { AccountContactView(purpose: .email) } label: {
                    row("邮箱", value: user?.email == nil ? "未绑定" : "已绑定", action: user?.email == nil ? "绑定" : "更换")
                }
            }
            Section {
                providerLink("苹果", provider: "apple")
                NavigationLink { WeChatBindingView() } label: {
                    row("微信", value: user?.providers?.contains("wechat") == true ? "已绑定" : "未绑定", action: "管理")
                }
                providerLink("微博", provider: "weibo")
                providerLink("QQ", provider: "qq")
            }
            Section {
                Button(L10n.t("注销账号"), role: .destructive) { delete = true }.disabled(busy)
                    .accessibilityIdentifier("account.delete")
                NavigationLink { AuthorizationManagementView() } label: { AppText("授权管理") }
            } footer: {
                if profile.isLocalOnly {
                    AppText("当前为本机档案。绑定和密码功能需先通过手机号或微信验证登录。注销会删除当前本机档案。")
                } else {
                    AppText("联系方式经服务端验证后生效。更换或设置密码后，其他设备的登录会失效。")
                }
            }
        }.scrollContentBackground(.hidden).background(OracleTheme.background).foregroundStyle(OracleTheme.ink)
            .navigationTitle(L10n.t("账号安全")).navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(L10n.t("确认注销账号？"), isPresented: $delete, titleVisibility: .visible) {
                Button(L10n.t("永久注销并删除当前档案"), role: .destructive) { Task { await deleteAccount() } }
            } message: {
                AppText("将删除当前账号、出生信息、问答和抽签记录，无法恢复。验证账号需在最近 10 分钟内重新登录后才能注销。")
            }
            .alert(L10n.t("账号提示"), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button(L10n.t("知道了"), role: .cancel) {}
            } message: { AppText(message ?? "") }
    }
    private func row(_ title: String, value: String, action: String) -> some View {
        HStack { AppText(title); Spacer(); AppText(value).font(.system(size: 12)).foregroundStyle(OracleTheme.muted); AppText(action).font(.system(size: 12)).foregroundStyle(OracleTheme.accent) }
    }
    private func maskPhone(_ phone: String?) -> String {
        guard let phone else { return "未绑定" }; return String(phone.prefix(3)) + "****" + String(phone.suffix(4))
    }
    private func providerLink(_ title: String, provider: String) -> some View {
        NavigationLink { ProviderBindingView(title: title) } label: {
            row(title, value: user?.providers?.contains(provider) == true ? "已绑定" : "未绑定", action: "绑定")
        }
    }
    private func deleteAccount() async {
        busy = true; defer { busy = false }
        do {
            if !profile.isLocalOnly { try await auth.deleteAccount() }
            account.deleteActiveProfile()
        } catch { message = error.localizedDescription }
    }
}

enum AccountContactPurpose: String {
    case phone, email, password
    var title: String { switch self { case .phone: "绑定或更换手机号"; case .email: "绑定邮箱"; case .password: "设置密码" } }
}

struct AccountContactView: View {
    let purpose: AccountContactPurpose
    @State private var auth = WeChatAuthService.shared
    @State private var target = ""
    @State private var code = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var challenge: WeChatAuthService.VerificationChallenge?
    @State private var resendAt = Date.distantPast
    @State private var busy = false
    @State private var message: String?
    private var verified: Bool { auth.authenticatedUser != nil }
    private var actualTarget: String {
        purpose == .password ? (auth.authenticatedUser?.phone ?? auth.authenticatedUser?.email ?? "") : target.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var validTarget: Bool {
        purpose == .password ? !actualTarget.isEmpty : (purpose == .phone ? AccountMethod.phone.isValid(actualTarget) : AccountMethod.email.isValid(actualTarget))
    }
    var body: some View {
        Form {
            Section {
                if purpose == .password {
                    AppText("验证码发送至已绑定的手机或邮箱。")
                    SecureField(L10n.t("新密码（8–128 位）"), text: $password).textContentType(.newPassword)
                    SecureField(L10n.t("再次输入密码"), text: $confirmation).textContentType(.newPassword)
                } else {
                    TextField(L10n.t(purpose == .phone ? "新手机号" : "邮箱地址"), text: $target)
                        .keyboardType(purpose == .phone ? .phonePad : .emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .onChange(of: target) { _, _ in challenge = nil; code = "" }
                }
                TextField(L10n.t("验证码"), text: $code).keyboardType(.numberPad).textContentType(.oneTimeCode)
                    .onChange(of: code) { _, value in code = String(value.filter(\.isNumber).prefix(6)) }
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = max(0, Int(ceil(resendAt.timeIntervalSince(context.date))))
                    Button(remaining > 0 ? "\(remaining) 秒后重新发送" : "发送验证码") { Task { await send() } }
                        .disabled(!verified || !validTarget || busy || remaining > 0)
                }
            } footer: {
                AppText(verified ? "验证码 5 分钟内有效。验证成功才会更新账号信息。" : "请先通过手机号或微信验证登录后使用此功能。")
            }
            Section {
                Button(L10n.t(busy ? "正在处理…" : "确认保存")) { Task { await save() } }
                    .disabled(busy || challenge == nil || code.count != 6 || (purpose == .password && (password.count < 8 || password.count > 128 || password != confirmation)))
            }
        }.scrollContentBackground(.hidden).background(OracleTheme.background)
            .navigationTitle(L10n.t(purpose.title)).navigationBarTitleDisplayMode(.inline)
            .alert(L10n.t("账号提示"), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button(L10n.t("知道了"), role: .cancel) {}
            } message: { AppText(message ?? "") }
    }
    private func send() async {
        busy = true; defer { busy = false }
        do {
            challenge = try await auth.sendCode(target: actualTarget, purpose: purpose.rawValue, channel: purpose == .email ? "email" : "sms")
            resendAt = .now.addingTimeInterval(Double(max(60, challenge?.resendAfter ?? 60)))
            message = "验证码已发送，请查看手机短信或邮箱。"
        } catch { message = error.localizedDescription }
    }
    private func save() async {
        guard let challenge, challenge.expiresAt > .now else { message = "验证码已过期，请重新获取。"; return }
        busy = true; defer { busy = false }
        do {
            try await auth.updateAccount(purpose: purpose.rawValue, target: actualTarget, challenge: challenge.challengeID, code: code, password: password)
            self.challenge = nil; code = ""; password = ""; confirmation = ""; message = "已保存。"
        } catch { message = error.localizedDescription }
    }
}

private struct WeChatBindingView: View {
    @State private var auth = WeChatAuthService.shared
    var body: some View {
        Form {
            AppText(auth.authenticatedUser?.providers?.contains("wechat") == true ? "已通过微信授权绑定。" : "使用官方微信授权，为当前账号绑定微信。")
            Button(L10n.t(auth.isBusy ? "等待微信授权…" : "前往微信授权")) { Task { await auth.beginLogin(forBinding: true) } }
                .disabled(auth.authenticatedUser == nil || !auth.canOfferLogin || auth.isBusy)
            if !auth.canOfferLogin { AppText("微信绑定暂未开放，请稍后再试。").font(.footnote).foregroundStyle(OracleTheme.muted) }
        }.scrollContentBackground(.hidden).background(OracleTheme.background).navigationTitle(L10n.t("微信绑定"))
            .alert(L10n.t("微信授权"), isPresented: Binding(get: { auth.errorMessage != nil }, set: { if !$0 { auth.errorMessage = nil } })) {
                Button(L10n.t("知道了"), role: .cancel) {}
            } message: { AppText(auth.errorMessage ?? "") }
    }
}

private struct ProviderBindingView: View {
    let title: String
    var body: some View {
        List { AppText("\(title)绑定暂未开放，请使用手机号、邮箱或微信管理账号。").font(.system(size: 15)).lineSpacing(6) }
            .scrollContentBackground(.hidden).background(OracleTheme.background).navigationTitle(L10n.t("\(title)绑定"))
    }
}

private struct AuthorizationManagementView: View {
    @State private var auth = WeChatAuthService.shared
    @State private var message: String?
    @State private var busy = false
    var body: some View {
        List {
            Section(L10n.t("已绑定的登录方式")) {
                if let providers = auth.authenticatedUser?.providers, !providers.isEmpty {
                    ForEach(providers, id: \.self) { provider in
                        Label(L10n.t(provider == "phone" ? "手机号" : provider == "email" ? "邮箱" : "微信"), systemImage: "checkmark.shield")
                    }
                } else { AppText("当前没有已验证的授权方式") }
            }
            Section {
                Button(L10n.t("退出其他设备的登录")) {
                    Task {
                        busy = true; defer { busy = false }
                        do { try await auth.revokeOtherSessions(); message = "其他设备的登录已失效。" }
                        catch { message = error.localizedDescription }
                    }
                }.disabled(auth.authenticatedUser == nil || busy)
            } footer: { AppText("应用不读取通讯录。微信授权范围和撤销也可在微信的授权管理中查看。") }
        }.scrollContentBackground(.hidden).background(OracleTheme.background).navigationTitle(L10n.t("授权管理"))
            .alert(L10n.t("授权管理"), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button(L10n.t("知道了"), role: .cancel) {}
            } message: { AppText(message ?? "") }
    }
}

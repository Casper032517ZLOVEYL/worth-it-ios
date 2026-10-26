import SwiftUI

struct RegistrationView: View {
    let account: AccountStore
    @State private var method: AccountMethod = .local
    @State private var identifier = ""
    @State private var consent = false
    @State private var birthStep = false
    @State private var showPrivacy = false
    @State private var nickname = ""
    @State private var birthday = Calendar.current.date(from: DateComponents(year: 1998, month: 6, day: 15, hour: 12))!
    @State private var knowsTime = false
    @State private var auth = WeChatAuthService.shared
    @State private var wechatUser: WeChatUser?
    @State private var code = ""
    @State private var challenge: WeChatAuthService.VerificationChallenge?
    @State private var resendAt = Date.distantPast
    @State private var phoneBusy = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack {
                    Label(L10n.t("值得吗？"), systemImage: "sparkle").font(.system(size: 20, weight: .semibold))
                    Spacer()
                    AppText(birthStep ? "02 / 02" : "01 / 02")
                        .font(.system(size: 11, design: .rounded)).foregroundStyle(OracleTheme.muted)
                }.padding(.bottom, 4)

                if birthStep {
                    birthForm
                } else {
                    identityForm
                }
            }
            .frame(maxWidth: 500).frame(maxWidth: .infinity)
            .padding(.horizontal, 28).padding(.top, 28).padding(.bottom, 30)
        }
        .scrollDismissesKeyboard(.interactively)
        .background {
            ZStack(alignment: .topTrailing) {
                OracleTheme.background
                Circle().fill(OracleTheme.accent.opacity(0.09)).frame(width: 320).blur(radius: 70).offset(x: 120, y: -80)
            }.ignoresSafeArea()
        }
        .foregroundStyle(OracleTheme.ink)
        .sheet(isPresented: $showPrivacy) { LocalPrivacyView() }
        .onChange(of: auth.authenticatedUser) { _, user in
            guard let user else { return }
            if method == .phone, account.resumeVerifiedPhone(user) { return }
            if account.resumeVerifiedWeChat(user) { return }
            wechatUser = user
            nickname = user.nickname
            birthStep = true
        }
        .alert(L10n.t("登录提示"), isPresented: Binding(get: { auth.errorMessage != nil }, set: { if !$0 { auth.errorMessage = nil } })) {
            Button(L10n.t("知道了")) { auth.errorMessage = nil }
        } message: { AppText(auth.errorMessage ?? "") }
    }

    private var identityForm: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "A SOFTER WAY TO KNOW YOURSELF", color: OracleTheme.accent)
                AppText("每一个选择，\n从认识自己开始。")
                    .font(.system(size: 33, weight: .medium)).lineSpacing(7)
                AppText("建立专属档案，把星光与心事留在这里。")
                    .font(.system(size: 14)).foregroundStyle(OracleTheme.muted)
            }
            OracleOrb().frame(height: 156).padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 20) {
                AppText("注册 / 继续本机档案").font(.system(size: 18, weight: .semibold))
                HStack(spacing: 6) {
                    ForEach([AccountMethod.local, .phone, .email]) { item in
                        Button {
                            method = item
                            identifier = ""; code = ""; challenge = nil
                        } label: {
                            Label(L10n.t(item.rawValue), systemImage: item.symbol)
                                .font(.system(size: 12, weight: .medium))
                                .frame(maxWidth: .infinity).padding(.vertical, 13)
                                .foregroundStyle(method == item ? OracleTheme.accent : OracleTheme.muted)
                                .background(method == item ? OracleTheme.accent.opacity(0.1) : .clear, in: Capsule())
                        }.buttonStyle(.plain).disabled(phoneBusy || auth.isBusy).accessibilityIdentifier("registerMethod.\(item.id)")
                    }
                }.padding(5).warmGlass(radius: 28)

                if method != .local {
                HStack(spacing: 12) {
                    if method == .phone {
                        AppText("+86").font(.system(size: 15, weight: .medium))
                        Rectangle().fill(OracleTheme.line).frame(width: 1, height: 20)
                    } else {
                        Image(systemName: method.symbol).foregroundStyle(OracleTheme.muted)
                    }
                    TextField(L10n.t(method.placeholder), text: $identifier)
                        .keyboardType(method == .phone ? .phonePad : method == .email ? .emailAddress : .asciiCapable)
                        .textContentType(method == .phone ? .telephoneNumber : method == .email ? .emailAddress : .username)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .focused($fieldFocused).font(.system(size: 15)).disabled(phoneBusy || auth.isBusy)
                        .submitLabel(.done).onSubmit { fieldFocused = false }
                        .accessibilityIdentifier("registrationIdentifier")
                        .onChange(of: identifier) { _, value in
                            challenge = nil; code = ""
                            if value.count > 100 { identifier = String(value.prefix(100)) }
                        }
                }
                .padding(18).background(OracleTheme.card, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(fieldFocused ? OracleTheme.accent : OracleTheme.line))
                AppText(method.formatHint).font(.system(size: 11)).foregroundStyle(OracleTheme.muted)
                } else {
                    AppText("无需手机号或邮箱，记录只保存在本机。")
                        .font(.system(size: 13)).foregroundStyle(OracleTheme.muted).lineSpacing(6)
                }

                if method == .phone {
                    HStack {
                        TextField(L10n.t("短信验证码"), text: $code)
                            .keyboardType(.numberPad).textContentType(.oneTimeCode)
                            .accessibilityIdentifier("smsCode")
                            .onChange(of: code) { _, value in code = String(value.filter(\.isNumber).prefix(6)) }
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let remaining = max(0, Int(ceil(resendAt.timeIntervalSince(context.date))))
                            Button(remaining > 0 ? L10n.f("%d 秒后重发", remaining) : L10n.t("获取验证码")) { Task { await sendSMS() } }
                                .font(.system(size: 12, weight: .medium))
                                .disabled(!consent || !method.isValid(identifier) || phoneBusy || remaining > 0)
                                .accessibilityIdentifier("sendSMSCode")
                        }
                    }.padding(18).background(OracleTheme.card, in: RoundedRectangle(cornerRadius: 18))
                    if challenge != nil {
                        AppText("验证码已发送，请查看手机短信，5 分钟内有效。")
                            .font(.system(size: 11)).foregroundStyle(OracleTheme.sage)
                    }
                }
                HStack(alignment: .top, spacing: 9) {
                    Button { consent.toggle() } label: {
                        Image(systemName: consent ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 23)).foregroundStyle(consent ? OracleTheme.accent : OracleTheme.muted)
                            .frame(width: 30, height: 32)
                    }.accessibilityLabel(L10n.t("了解并同意隐私与使用说明"))
                        .accessibilityAddTraits(consent ? .isSelected : []).accessibilityIdentifier("registrationConsent")
                    VStack(alignment: .leading, spacing: 5) {
                        AppText("我已了解并同意").foregroundStyle(OracleTheme.muted)
                        Button(L10n.t("《隐私与使用说明》")) { fieldFocused = false; showPrivacy = true }
                            .foregroundStyle(OracleTheme.accent)
                    }.font(.system(size: 12)).padding(.top, 2)
                }
                PrimaryButton(title: "继续，开启我的星笺", enabled: (method == .local || method.isValid(identifier)) && consent && !phoneBusy && (method != .phone || (challenge != nil && code.count == 6))) {
                    fieldFocused = false
                    if method == .local { identifier = UUID().uuidString; birthStep = true; return }
                    if method == .phone { Task { await verifySMS() }; return }
                    if let existing = account.existing(method: method, identifier: identifier) {
                        account.resume(existing)
                    } else {
                        withAnimation { birthStep = true }
                    }
                }.accessibilityIdentifier("registrationContinue")
                if method == .local {
                    ForEach(account.profiles.filter { $0.method == .local }) { saved in
                        Button { account.resume(saved) } label: {
                            HStack { AppText(saved.nickname); Spacer(); AppText("继续本机档案"); Image(systemName: "chevron.right") }
                        }.font(.system(size: 13)).accessibilityIdentifier("resumeLocal.\(saved.id)")
                    }
                }
                if auth.canOfferLogin {
                    Button { Task { await auth.beginLogin() } } label: {
                        HStack(spacing: 9) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                            AppText(auth.isBusy ? "等待微信授权…" : "通过微信授权继续")
                            if auth.isBusy { ProgressView() }
                        }.font(.system(size: 14, weight: .medium)).frame(maxWidth: .infinity).padding(.vertical, 16)
                            .foregroundStyle(OracleTheme.sage)
                            .overlay(Capsule().stroke(OracleTheme.line))
                    }.disabled(!consent || auth.isBusy).accessibilityIdentifier("weChatAuthorize")
                }
            }

            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "iphone.gen3.radiowaves.left.and.right").font(.system(size: 16))
                AppText(method == .local ? "本机档案不创建互联网账号，也不上传答题和出生信息。请妥善保管设备。" : method == .phone ? "手机号需通过真实短信验证后登录。验证码不会显示在应用内。" : "邮箱目前用于本机建档，尚未验证邮箱所有权。正式账号可使用手机号或微信授权登录。")
                    .font(.system(size: 11)).lineSpacing(5)
            }.foregroundStyle(OracleTheme.muted)
        }
    }

    private func sendSMS() async {
        phoneBusy = true; defer { phoneBusy = false }
        do {
            let result = try await auth.sendCode(target: method.normalized(identifier))
            challenge = result; resendAt = .now.addingTimeInterval(Double(max(60, result.resendAfter)))
        } catch { auth.errorMessage = error.localizedDescription }
    }
    private func verifySMS() async {
        guard let challenge, challenge.expiresAt > .now else { auth.errorMessage = "验证码已过期，请重新获取。"; return }
        phoneBusy = true; defer { phoneBusy = false }
        do {
            let user = try await auth.verifyPhone(target: method.normalized(identifier), challenge: challenge.challengeID, code: code)
            if !account.resumeVerifiedPhone(user) { wechatUser = user; birthStep = true }
        } catch { auth.errorMessage = error.localizedDescription }
    }

    private var birthForm: some View {
        VStack(alignment: .leading, spacing: 26) {
            Button { birthStep = false; wechatUser = nil; auth.signOut() } label: { Label(L10n.t("返回注册方式"), systemImage: "arrow.left").font(.system(size: 13)) }
            VStack(alignment: .leading, spacing: 13) {
                Eyebrow(text: "YOUR OWN LITTLE CONSTELLATION", color: OracleTheme.accent)
                AppText("把你的星光，\n轻轻写在这里。")
                    .font(.system(size: 33, weight: .medium)).lineSpacing(7)
                AppText("出生信息只用于你的专属星座属性和内容灵感。")
                    .font(.system(size: 13)).foregroundStyle(OracleTheme.muted).lineSpacing(5)
            }
            BirthFields(nickname: $nickname, birthday: $birthday, knowsTime: $knowsTime)
            ZodiacIdentityCard(birth: BirthDetails(date: birthday, includeTime: knowsTime))
            PrimaryButton(title: "生成档案，进入值得吗？", enabled: !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                if let wechatUser, wechatUser.phone != nil, method == .phone {
                    account.registerPhone(wechatUser, nickname: nickname, birth: BirthDetails(date: birthday, includeTime: knowsTime))
                } else if let wechatUser {
                    account.registerWeChat(wechatUser, nickname: nickname, birth: BirthDetails(date: birthday, includeTime: knowsTime))
                } else {
                    _ = account.register(method: method, identifier: identifier, nickname: nickname,
                                         birth: BirthDetails(date: birthday, includeTime: knowsTime))
                }
            }.accessibilityIdentifier("finishRegistration")
            AppText("星座采用常见生日区间，临界日期仅作娱乐。出生时间细化节律标签；未计算上升星座或完整星盘。")
                .font(.system(size: 11)).foregroundStyle(OracleTheme.muted).lineSpacing(5)
        }
    }
}

struct BirthFields: View {
    @Binding var nickname: String
    @Binding var birthday: Date
    @Binding var knowsTime: Bool
    private var earliest: Date { Calendar.current.date(from: DateComponents(year: 1900, month: 1, day: 1))! }
    var body: some View {
        OracleCard {
            VStack(alignment: .leading, spacing: 20) {
                TextField(L10n.t("怎么称呼你？"), text: $nickname)
                    .font(.system(size: 17)).textContentType(.nickname)
                    .accessibilityIdentifier("profileNickname")
                    .onChange(of: nickname) { _, text in if text.count > 20 { nickname = String(text.prefix(20)) } }
                Divider().overlay(OracleTheme.line)
                DatePicker(L10n.t("出生年月日"), selection: $birthday, in: earliest...Date(), displayedComponents: .date)
                    .font(.system(size: 14)).accessibilityIdentifier("profileBirthday")
                Toggle(L10n.t("我知道出生时间"), isOn: $knowsTime).font(.system(size: 14))
                    .tint(OracleTheme.accent).accessibilityIdentifier("birthTimeKnown")
                if knowsTime {
                    DatePicker(L10n.t("出生时间"), selection: $birthday, displayedComponents: .hourAndMinute)
                        .font(.system(size: 14)).accessibilityIdentifier("profileBirthTime")
                    AppText("填写出生地当地的钟表时间，可精确到分钟。")
                        .font(.system(size: 11)).foregroundStyle(OracleTheme.muted)
                } else {
                    AppText("不知道几点也没关系，留空即可。")
                        .font(.system(size: 11)).foregroundStyle(OracleTheme.muted)
                }
            }
        }
    }
}

struct ZodiacIdentityCard: View {
    let birth: BirthDetails
    private var sign: ZodiacSign { .forBirthday(month: birth.month, day: birth.day) }
    var body: some View {
        HStack(spacing: 18) {
            AppText(sign.glyph).font(.system(size: 46, weight: .light))
                .foregroundStyle(OracleTheme.accent).frame(width: 74, height: 82)
                .background(OracleTheme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 25))
            VStack(alignment: .leading, spacing: 9) {
                AppText(sign.name).font(.system(size: 21, weight: .medium))
                AppText("\(L10n.t(sign.element)) · \(L10n.t(sign.mode)) · \(L10n.t(birth.rhythm))")
                    .font(.system(size: 11)).foregroundStyle(OracleTheme.muted)
                AppText(sign.keywords.map { L10n.t($0) }.joined(separator: " / ")).font(.system(size: 12)).foregroundStyle(OracleTheme.sage)
            }
            Spacer(minLength: 0)
        }.padding(18).warmGlass()
    }
}

struct LocalPrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    AppText("把星光留在身边，\n把选择留给自己。")
                        .font(.system(size: 28, weight: .medium)).lineSpacing(6)
                    if !ReleaseInformation.value("AppOwnerName").isEmpty {
                        AppText(ReleaseInformation.value("AppOwnerName")).font(.headline)
                    }
                    if let url = ReleaseInformation.privacyURL { Link(L10n.t("在线隐私政策"), destination: url) }
                    if let url = ReleaseInformation.termsURL { Link(L10n.t("使用条款"), destination: url) }
                    if let url = ReleaseInformation.supportMailURL { Link(L10n.t("联系支持"), destination: url) }
                    AppText("本机档案") .font(.headline)
                    AppText("手机号由服务端通过短信验证码验证后登录；短信发送需要处理手机号及防滥用信息。邮箱本机建档尚未验证所有权，熟悉这台设备的人可能用相同邮箱继续这个本机档案。设置密码、绑定或更换联系方式通过服务端及验证码校验。微信使用官方 SDK 授权，必须通过配置好的服务端校验才可进入。微信未安装或配置未完成时，不显示授权入口。")
                    AppText("信息与存储").font(.headline)
                    AppText("出生信息、答题和小任务记录只保存在设备中。使用手机号时，手机号和验证码发送至登录服务，短信由腾讯云服务发送；验证码只在服务端保存带密钥摘要，不返回 App。使用微信时，授权 code 和 state 发送到你配置的登录服务，由它与微信完成身份校验；AppSecret 与微信访问凭证留在服务端。应用自己的登录凭证保存在本机 Keychain，微信 SDK 按其规则处理授权通信。设备备份由系统设置决定，卸载可能移除本机记录。不同档案的问答历史和抽签记录分别保存。设置中的清除缓存会删除当前档案的问答历史与草稿；注销账号会删除服务端账号及本机当前档案记录。")
                    AppText("树洞聊天").font(.headline)
                    AppText("树洞由 AI 生成回复。只有阅读发送说明并同意后，你主动发送的内容及最近最多 10 轮聊天才会经应用后端转交模型服务商；出生资料、问答和抽签记录不会自动上传。模型密钥只在服务端配置。对话与草稿按本机档案保存，可在树洞菜单删除或撤回后续发送授权；注销档案也会删除其本机聊天记录。参考后端不保存聊天正文；服务商的保留规则以发送前展示的隐私政策为准。")
                    AppText("怎样理解星笺").font(.headline)
                    AppText("星座属性按常见生日区间生成；节律标签来自可选出生时间，星座档案在补全出生时间、地点和时区后可在本机计算星体及整宫制宫位；占星释义仅供文化阅读。日、周、月、年的分数与幸运提示是个性化娱乐内容，不是真实运势、成功率或对你的心理诊断。")
                    AppText("答题与小事").font(.headline)
                    AppText("五条解读会标注是否引用最近一次已完成的答题。没有答题时不会假设你已经作答。小任务是可跳过的日常休息建议，不提供治疗效果承诺。涉及投资、健康或其他重大事务，请结合事实与合适的专业支持。")
                }.font(.system(size: 14)).lineSpacing(7).padding(26)
            }
            .background(OracleTheme.background).foregroundStyle(OracleTheme.ink)
            .navigationTitle(L10n.t("隐私与使用说明")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.t("完成")) { dismiss() } } }
        }.tint(OracleTheme.accent).presentationDragIndicator(.visible)
    }
}

import SwiftUI
import UIKit

struct SettingsView: View {
    @Bindable var account: AccountStore
    let profile: UserProfile
    let decisions: DecisionStore
    @State private var clear = false
    @State private var signOut = false
    @State private var privacy = false
    @State private var share = false
    @State private var cleared = false
    var body: some View {
        List {
            Section {
                NavigationLink { AccountSecurityView(account: account, profile: profile) } label: {
                    Label(L10n.t("账号安全"), systemImage: "person.badge.shield.checkmark")
                }.accessibilityIdentifier("settings.accountSecurity")
            }
            Section {
                NavigationLink { LanguageSettingsView(account: account) } label: {
                    settingLabel("语言设置", symbol: "character.bubble", value: account.language.nativeName)
                }
                NavigationLink { DisplaySettingsView(account: account) } label: {
                    settingLabel("显示设置", symbol: "circle.lefthalf.filled", value: account.appearance.rawValue)
                }.accessibilityIdentifier("settings.display")
            }
            Section {
                Button { share = true } label: { Label(L10n.t("推荐给好友"), systemImage: "hand.thumbsup") }
                    .accessibilityIdentifier("settings.share")
                Button { clear = true } label: {
                    settingLabel("清除缓存", symbol: "eraser", value: L10n.f("%d 份问答记录", decisions.reports.count))
                }.accessibilityIdentifier("settings.clearHistory")
                NavigationLink { AboutAppView() } label: {
                    settingLabel("关于值得吗？", symbol: "info.circle", value: "版本 1.0")
                }
            }
            Section {
                Button(L10n.t("退出登录"), role: .destructive) { signOut = true }
                    .frame(maxWidth: .infinity).accessibilityIdentifier("signOut")
            }
            Section {
                Button { privacy = true } label: {
                    AppText("数据隐私  ·  内容说明").font(.system(size: 13)).frame(maxWidth: .infinity)
                }.accessibilityIdentifier("settings.privacy")
            } footer: {
                AppText("愿每一次选择，都更接近你自己。")
                    .frame(maxWidth: .infinity).padding(.top, 15)
            }
        }
        .scrollContentBackground(.hidden).background(OracleTheme.background).foregroundStyle(OracleTheme.ink)
        .navigationTitle(L10n.t("设置")).navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
        .sheet(isPresented: $privacy) { LocalPrivacyView() }
        .sheet(isPresented: $share) {
            ActivityShare(items: ["大决定之前，先看清自己。来「值得吗？」做一次 20 问自问，或摇一支问心签。"])
                .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        }
        .confirmationDialog(L10n.t("清除当前档案的问答记录？"), isPresented: $clear, titleVisibility: .visible) {
            Button(L10n.t("清除问答历史和草稿"), role: .destructive) { decisions.clearHistory(); cleared = true }
        } message: { AppText("将删除已完成的问答、解读和未完成草稿。出生档案、抽签记录、树洞对话与显示设置会保留。此操作无法撤销。") }
        .confirmationDialog(L10n.t("退出登录？"), isPresented: $signOut, titleVisibility: .visible) {
            Button(L10n.t("退出登录"), role: .destructive) { WeChatAuthService.shared.signOut(); account.signOut() }
        } message: { AppText("本机记录会保留。手机号和微信账号再次进入时需要重新验证。") }
        .alert(L10n.t("已清除问答记录"), isPresented: $cleared) { Button(L10n.t("完成"), role: .cancel) {} }
    }
    private func settingLabel(_ title: String, symbol: String, value: String) -> some View {
        HStack {
            Label(L10n.t(title), systemImage: symbol)
            Spacer()
            AppText(value).font(.system(size: 12)).foregroundStyle(OracleTheme.muted)
        }
    }
}

struct DisplaySettingsView: View {
    @Bindable var account: AccountStore
    var body: some View {
        List {
            Section(L10n.t("界面样式")) {
                ForEach(AppAppearance.allCases) { style in
                    Button { account.appearance = style } label: {
                        HStack {
                            Label(L10n.t(style.rawValue), systemImage: style.symbol)
                            Spacer()
                            if account.appearance == style { Image(systemName: "checkmark").foregroundStyle(OracleTheme.accent) }
                        }.foregroundStyle(OracleTheme.ink)
                    }.accessibilityIdentifier("appearance.\(style.rawValue)")
                        .accessibilityAddTraits(account.appearance == style ? .isSelected : [])
                }
            }
            Section {
                Label(L10n.t("Liquid Glass"), systemImage: "drop.halffull")
            } footer: {
                AppText("支持的系统会自动使用原生液态玻璃。开启系统“降低透明度”时，界面会改用清晰的实色。奶油、陶土与鼠尾草色在浅色和深色下分别适配。")
            }
        }.scrollContentBackground(.hidden).background(OracleTheme.background)
            .navigationTitle(L10n.t("显示设置")).navigationBarTitleDisplayMode(.inline)
    }
}

struct LanguageSettingsView: View {
    @Bindable var account: AccountStore
    @State private var search = ""
    private var languages: [AppLanguage] {
        AppLanguage.allCases.filter { search.isEmpty || $0.nativeName.localizedCaseInsensitiveContains(search) || $0.rawValue.localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        List {
            Section {
                ForEach(languages) { language in
                    Button { account.language = language } label: {
                        HStack {
                            AppText(language.nativeName).foregroundStyle(OracleTheme.ink)
                            Spacer()
                            if account.language == language { Image(systemName: "checkmark").foregroundStyle(OracleTheme.accent) }
                        }
                    }.accessibilityIdentifier("language.\(language.rawValue)")
                        .accessibilityAddTraits(account.language == language ? .isSelected : [])
                }
            } footer: { AppText("界面与问答支持 28 种语言；古典签诗保留中文原文，长篇内容在未翻译时显示原文。") }
        }.searchable(text: $search, prompt: "搜索语言")
            .scrollContentBackground(.hidden).background(OracleTheme.background)
            .navigationTitle(L10n.t("语言设置")).navigationBarTitleDisplayMode(.inline)
    }
}

private struct AboutAppView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                OracleOrb().frame(height: 180)
                AppText("值得吗？").font(.system(size: 32, weight: .medium))
                AppText("星笺 · 自问 · 问心签").foregroundStyle(OracleTheme.accent)
                AppText("用二十个问题，整理动机、事实、资源、风险与独立判断；用一点轻轻的仪式，留意当下的心情。")
                AppText("准备度来自自我报告，不代表实际成功概率。星座分数和幸运提示仅供娱乐；问心签是传统签文化启发的原创文字，不作吉凶预测。")
                NavigationLink { ContentSourcesView() } label: { Label(L10n.t("版本与来源"), systemImage: "books.vertical") }
                if let url = ReleaseInformation.supportURL { Link(L10n.t("帮助与支持"), destination: url) }
                if let url = ReleaseInformation.supportMailURL { Link(L10n.t("联系支持"), destination: url) }
                AppText("版本 1.0").font(.footnote).foregroundStyle(OracleTheme.muted)
            }.font(.system(size: 15)).lineSpacing(7).padding(26)
        }.background(OracleTheme.background).foregroundStyle(OracleTheme.ink)
            .navigationTitle(L10n.t("关于值得吗？")).navigationBarTitleDisplayMode(.inline)
    }
}

struct ActivityShare: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

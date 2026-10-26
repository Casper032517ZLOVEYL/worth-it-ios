import SwiftUI

enum OracleRoute: Hashable {
    case settings
    case starDetails
    case history
    case questions
    case report(UUID)
}

struct ContentView: View {
    let account: AccountStore
    let profile: UserProfile
    @State private var store: DecisionStore
    @State private var lottery: LotteryStore
    @State private var treeHole: TreeHoleStore
    @State private var path: [OracleRoute] = []
    @State private var selectedTab = 0
    @State private var title = ""
    @State private var category: DecisionCategory = .career
    @State private var showAbout = false
    @State private var replaceDraft = false
    @FocusState private var titleFocused: Bool

    init(account: AccountStore, profile: UserProfile) {
        self.account = account
        self.profile = profile
        _store = State(initialValue: account.decisionStore(for: profile))
        _lottery = State(initialValue: account.lotteryStore(for: profile))
        _treeHole = State(initialValue: account.treeHoleStore(for: profile))
    }

    var body: some View {
        NavigationStack(path: $path) {
            TabView(selection: $selectedTab) {
                ForEach(0..<5) { index in
                    tabPage(index)
                        .tabItem {
                            Label(L10n.t(tabLabels[index]), systemImage: tabSymbols[index])
                                .accessibilityIdentifier("tab.\(tabLabels[index])")
                        }
                        .tag(index)
                }
            }
            .onChange(of: selectedTab) { _, _ in titleFocused = false }
            .navigationDestination(for: OracleRoute.self) { route in
                switch route {
                case .settings:
                    SettingsView(account: account, profile: profile, decisions: store)
                case .starDetails:
                    ScrollView {
                        StarHomeView(profile: profile, account: account, latestReport: store.reports.first) { path = []; selectedTab = 1 }
                            .frame(maxWidth: 540).frame(maxWidth: .infinity).padding(24)
                    }.background(OracleTheme.background).navigationTitle(L10n.t("星笺详情"))
                        .navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
                case .history:
                    ScrollView { journal.padding(24) }.background(OracleTheme.background).navigationTitle(L10n.t("问答历史"))
                        .navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
                case .questions:
                    if let draft = store.draft {
                        QuestionFlowView(store: store, initialDraft: draft, close: { path = [] }) { report in
                            path = [.report(report.id)]
                        }
                    }
                case .report(let id):
                    if let report = store.reports.first(where: { $0.id == id }) {
                        ReportView(report: report, store: store, close: { path = [] })
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(OracleTheme.accent)
        .sheet(isPresented: $showAbout) { about }
        .confirmationDialog(L10n.t("开始新的决定？"), isPresented: $replaceDraft, titleVisibility: .visible) {
            Button(L10n.t("替换未完成的答题"), role: .destructive) { startNew() }
            Button(L10n.t("继续之前的答题")) { path.append(.questions) }
        } message: { AppText("新决定会替换当前草稿，已经保存的决定签不受影响。") }
        .alert(L10n.t("本地存储提示"), isPresented: Binding(get: { store.storageError != nil }, set: { if !$0 { store.storageError = nil } })) {
            Button(L10n.t("知道了")) { store.storageError = nil }
        } message: { AppText(store.storageError ?? "") }
    }

    private var masthead: some View {
        HStack {
            HStack(spacing: 9) {
                Image(systemName: "asterisk").font(.system(size: 27, weight: .medium)).foregroundStyle(OracleTheme.accent)
                AppText("值得吗？").font(.system(size: 21, weight: .bold))
            }
            Spacer()
            Button { showAbout = true } label: {
                Image(systemName: "questionmark").font(.system(size: 13, weight: .medium))
                    .frame(width: 36, height: 36).warmGlass(radius: 18)
            }.foregroundStyle(OracleTheme.muted).accessibilityLabel(L10n.t("使用说明"))
            Button { path.append(.settings) } label: {
                Image(systemName: "slider.horizontal.3").font(.system(size: 14))
                    .frame(width: 36, height: 36).warmGlass(radius: 18)
            }.foregroundStyle(OracleTheme.muted).accessibilityLabel(L10n.t("设置")).accessibilityIdentifier("openSettings")
        }.foregroundStyle(OracleTheme.ink)
    }

    private var home: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 7) {
                    Circle().fill(OracleTheme.accent).frame(width: 5, height: 5)
                    Eyebrow(text: "A LITTLE PAUSE. A CLEARER CHOICE.")
                }
                AppText("大决定之前，\n先看清自己。")
                    .font(.system(size: 34, weight: .medium)).tracking(-1).lineSpacing(5)
                    .foregroundStyle(OracleTheme.ink)
                AppText("给直觉一点空间，也给理性一个发言权。")
                    .font(.system(size: 13)).foregroundStyle(OracleTheme.muted)
            }

            ZStack(alignment: .bottom) {
                OracleOrb().frame(width: 200, height: 175).padding(.bottom, 19)
                HStack(spacing: 22) {
                    Label(L10n.t("20 个问题"), systemImage: "circle.grid.3x3")
                    AppText("·")
                    Label(L10n.t("约 4 分钟"), systemImage: "clock")
                }
                .font(.system(size: 11)).foregroundStyle(OracleTheme.muted)
            }.frame(maxWidth: .infinity).padding(.top, -10)

            if let draft = store.draft {
                Button { titleFocused = false; path.append(.questions) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.clockwise").foregroundStyle(OracleTheme.accent)
                        VStack(alignment: .leading, spacing: 5) {
                            AppText("继续上次的思考").font(.system(size: 13, weight: .semibold))
                            AppText("\(draft.title) · 已答 \(draft.answers.count)/20 题").font(.system(size: 11)).foregroundStyle(OracleTheme.muted).lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12))
                    }.padding(17).background(OracleTheme.card, in: RoundedRectangle(cornerRadius: 17))
                }.buttonStyle(.plain).foregroundStyle(OracleTheme.ink)
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    AppText("你正在犹豫什么？").font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Eyebrow(text: "THE BIG QUESTION", color: OracleTheme.muted)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(DecisionCategory.allCases) { item in
                            Button { category = item } label: {
                                Label(L10n.t(item.rawValue), systemImage: item.symbol)
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                    .background(category == item ? OracleTheme.accent : OracleTheme.card, in: Capsule())
                    .foregroundStyle(category == item ? OracleTheme.buttonInk : OracleTheme.muted)
                            }.buttonStyle(.plain)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    TextField(category.example, text: $title, prompt: SwiftUI.Text(verbatim: L10n.t(category.example)).foregroundStyle(OracleTheme.muted), axis: .vertical)
                        .font(.system(size: 15)).lineSpacing(6).lineLimit(2...3)
                        .focused($titleFocused).tint(OracleTheme.accent)
                        .accessibilityIdentifier("decisionInput")
                        .onChange(of: title) { _, value in if value.count > 120 { title = String(value.prefix(120)) } }
                    HStack {
                        AppText("把它写下来，答案从这里开始。")
                        Spacer()
                        AppText("\(title.count)/120").monospacedDigit()
                    }.font(.system(size: 10)).foregroundStyle(OracleTheme.muted)
                }
                .padding(18).background(OracleTheme.card, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(titleFocused ? OracleTheme.accent.opacity(0.6) : OracleTheme.line))

                PrimaryButton(title: "开始解读我的决定", enabled: !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                    titleFocused = false
                    if store.draft != nil { replaceDraft = true } else { startNew() }
                }.accessibilityIdentifier("startDecision")
            }


        }.foregroundStyle(OracleTheme.ink)
    }

    private var journal: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "YOUR DECISION JOURNAL", color: OracleTheme.sage)
                AppText("每一次选择，\n都有迹可循。")
                    .font(.system(size: 35, weight: .medium)).lineSpacing(5)
                AppText("\(store.reports.count) 份决定签 · 留给未来的自己")
                    .font(.system(size: 13)).foregroundStyle(OracleTheme.muted)
            }
            if store.reports.isEmpty {
                OracleCard {
                    VStack(alignment: .leading, spacing: 20) {
                        Image(systemName: "tray").font(.system(size: 36, weight: .ultraLight)).foregroundStyle(OracleTheme.sage)
                        AppText("第一份决定签，等你来写。")
                            .font(.system(size: 19, weight: .medium))
                        AppText("完成 20 个问题后，你的心态画像和行动建议会出现在这里。以后再回来，看看当时的自己。")
                            .font(.system(size: 14)).foregroundStyle(OracleTheme.muted).lineSpacing(6)
                        PrimaryButton(title: "去问问自己") { path = []; selectedTab = 1 }
                    }
                }
            } else {
                ForEach(store.reports) { report in
                    Button { path.append(.report(report.id)) } label: {
                        OracleCard {
                            VStack(alignment: .leading, spacing: 17) {
                                HStack {
                                    Label(L10n.t(report.category.rawValue), systemImage: report.category.symbol)
                                    Spacer()
                                    AppText(report.date.formatted(.dateTime.year().month().day()))
                                }.font(.system(size: 11)).foregroundStyle(OracleTheme.muted)
                                AppText(report.title).font(.system(size: 20, weight: .medium)).lineLimit(2).multilineTextAlignment(.leading)
                                HStack {
                                    AppText(report.archetype).font(.system(size: 12, weight: .medium)).foregroundStyle(OracleTheme.sage)
                                    Spacer()
                                    AppText("\(report.score)").font(.system(size: 25, weight: .light, design: .rounded)).foregroundStyle(OracleTheme.accent)
                                    AppText("/ 100").font(.system(size: 10)).foregroundStyle(OracleTheme.muted)
                                    Image(systemName: "arrow.up.right").font(.system(size: 14)).padding(.leading, 6)
                                }
                            }
                        }
                    }.buttonStyle(.plain)
                }
            }
        }.foregroundStyle(OracleTheme.ink)
    }

    private let tabLabels = ["星笺", "问一问", "树洞", "问心签", "我的"]
    private let tabSymbols = ["sun.horizon", "sparkle", "leaf", "lines.measurement.vertical", "person.crop.circle"]

    // The native tab bar owns the lift, lens magnification, refraction and drag gesture.
    // iOS 26+ renders Liquid Glass; older supported systems use their native tab bar.
    @ViewBuilder private func tabPage(_ index: Int) -> some View {
        if index == 2 {
            TreeHoleView(store: treeHole)
        } else {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                masthead
                if index == 0 {
                    StarDashboardView(profile: profile, latestReport: store.reports.first, details: { path.append(.starDetails) }, ask: { selectedTab = 1 })
                } else if index == 1 {
                    home
                } else if index == 3 {
                    LotteryView(store: lottery)
                } else {
                    ProfileSettingsView(account: account, profile: profile) { path.append(.history) }
                }
            }
            .frame(maxWidth: 540).frame(maxWidth: .infinity)
            .padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(OracleTheme.background)
        }
    }

    private var about: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Eyebrow(text: "BEFORE YOU DECIDE", color: OracleTheme.accent)
                    Spacer()
                    Button(L10n.t("完成")) { showAbout = false }.font(.system(size: 14))
                }
                AppText("不是预言，\n是一次看见自己。")
                    .font(.system(size: 30, weight: .medium)).lineSpacing(6)
                AppText("「值得吗？」用 20 个自问，帮你整理动机、事实、资源、风险和独立判断。请按真实状态回答，不必寻找“正确答案”。")
                AppText("每题按准备程度记 0–3 分。每个维度 4 题，共 12 分；总分 60 分，换算成 0–100 的准备度。它来自你的自我报告，没有经过预测效度验证，不是实际成功率。")
                AppText("若你正处于强烈情绪中，或认为失败会超出承受范围，结果会优先建议暂缓；高总分也不会覆盖这些信号。")
                AppText("这是一款自我反思工具。它不能替代专业判断，也不替你做医疗、法律或投资决定。答题、抽签与出生资料保存在本机。树洞仅在你同意并发送时，将聊天内容交由配置的模型服务生成回复。卸载应用可能会移除本机记录。")
                AppText("未来不是被算出来的，\n是被你一步一步走出来的。")
                    .foregroundStyle(OracleTheme.sage).padding(.top, 8)
            }
            .font(.system(size: 14)).lineSpacing(7).padding(28)
        }
        .foregroundStyle(OracleTheme.ink).presentationDragIndicator(.visible)
        .presentationBackground(OracleTheme.background)
    }

    private func startNew() {
        store.draft = DecisionDraft(title: title.trimmingCharacters(in: .whitespacesAndNewlines), category: category)
        store.persist()
        path.append(.questions)
    }
}

#Preview { AppRootView() }

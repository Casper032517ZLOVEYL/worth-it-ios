import SwiftUI

struct ReportView: View {
    let report: DecisionReport
    let store: DecisionStore
    let close: () -> Void
    @State private var showAnswers = false
    @State private var showDelete = false
    @State private var reflection: String
    @FocusState private var reflectionFocused: Bool

    init(report: DecisionReport, store: DecisionStore, close: @escaping () -> Void) {
        self.report = report
        self.store = store
        self.close = close
        _reflection = State(initialValue: report.reflection)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeader(title: "你的决定签", subtitle: "THE INNER ORACLE", back: close)
                    .padding(.bottom, 6)
                verdictCard
                dimensionCard
                actionCard
                reflectionCard
                answersCard
                HStack(spacing: 14) {
                    ShareLink(item: report.shareText) {
                        Label(L10n.t("分享决定签"), systemImage: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .medium)).frame(maxWidth: .infinity).frame(minHeight: 54)
                            .background(OracleTheme.card, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(OracleTheme.line))
                    }
                    Button { showDelete = true } label: {
                        Image(systemName: "trash").frame(width: 54, height: 54)
                            .background(OracleTheme.card, in: RoundedRectangle(cornerRadius: 16))
                    }.accessibilityLabel(L10n.t("删除这份决定签"))
                }
                VStack(spacing: 7) {
                    AppText("命运不在签里，在你接下来的行动里。")
                        .foregroundStyle(OracleTheme.sage)
                    AppText("准备度来自自我报告，不代表真实成功概率。")
                        .foregroundStyle(OracleTheme.muted)
                }.font(.system(size: 10)).frame(maxWidth: .infinity).padding(.vertical, 5)
                PrimaryButton(title: "带着答案，回到生活里", symbol: "arrow.turn.up.left", action: close)
            }
            .frame(maxWidth: 540).frame(maxWidth: .infinity)
            .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 30)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(OracleTheme.background).foregroundStyle(OracleTheme.ink)
        .toolbar(.hidden, for: .navigationBar).navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) { Spacer(); Button(L10n.t("完成")) { reflectionFocused = false } }
        }
        .confirmationDialog(L10n.t("删除这份决定签？"), isPresented: $showDelete, titleVisibility: .visible) {
            Button(L10n.t("永久删除"), role: .destructive) { close(); store.delete(id: report.id) }
            Button(L10n.t("保留"), role: .cancel) {}
        } message: { AppText("删除后无法恢复，其他决定签不受影响。") }
    }

    private var verdictCard: some View {
        VStack(spacing: 18) {
            HStack {
                Eyebrow(text: "DECISION / \(report.date.formatted(.dateTime.month(.twoDigits).day(.twoDigits)))", color: OracleTheme.sage)
                Spacer()
                AppText(report.category.rawValue).font(.system(size: 11)).foregroundStyle(OracleTheme.muted)
            }
            AppText(report.title).font(.system(size: 16, weight: .medium))
                .multilineTextAlignment(.center).lineSpacing(5).fixedSize(horizontal: false, vertical: true).padding(.top, 3)
            ZStack {
                OracleOrb(compact: true).frame(width: 208, height: 195).opacity(0.45)
                VStack(spacing: 0) {
                    AppText("\(report.score)").font(.system(size: 75, weight: .light, design: .rounded)).tracking(-4)
                    Eyebrow(text: "准备度 / 100", color: OracleTheme.accent)
                }
            }.padding(.vertical, -8)
            AppText(report.archetype).font(.system(size: 27, weight: .medium)).foregroundStyle(OracleTheme.accent)
            AppText(report.verdict).font(.system(size: 14)).multilineTextAlignment(.center)
            Rectangle().fill(OracleTheme.line).frame(height: 1).padding(.top, 4)
            HStack {
                Label(L10n.t("已存入决定簿"), systemImage: "checkmark.circle")
                Spacer()
                AppText(L10n.f("%d / %d 个真实回答", report.questionCount, report.questionCount))
            }.font(.system(size: 10)).foregroundStyle(OracleTheme.muted)
        }
        .padding(23)
        .background {
            RoundedRectangle(cornerRadius: 28)
                .fill(LinearGradient(colors: [OracleTheme.accent.opacity(0.12), OracleTheme.card], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(OracleTheme.sage.opacity(0.24)))
    }

    private var dimensionCard: some View {
        OracleCard {
            VStack(alignment: .leading, spacing: 21) {
                sectionTitle("你的内心坐标", english: "MIND MAP")
                ForEach(report.dimensions) { item in
                    VStack(spacing: 10) {
                        HStack {
                            Label(L10n.t(item.dimension.rawValue), systemImage: item.dimension.symbol)
                                .font(.system(size: 12)).foregroundStyle(OracleTheme.ink)
                            Spacer()
                            AppText("\(item.value)").font(.system(size: 12, design: .rounded))
                                .foregroundStyle(item.dimension == report.weakest.dimension ? OracleTheme.sage : OracleTheme.accent)
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(OracleTheme.line)
                                Capsule().fill(item.dimension == report.weakest.dimension ? OracleTheme.sage : OracleTheme.accent)
                                    .frame(width: proxy.size.width * Double(item.value) / 100)
                            }
                        }.frame(height: 4)
                    }.accessibilityElement(children: .ignore)
                        .accessibilityLabel(L10n.t("\(item.dimension.rawValue)，\(item.value) 分"))
                }
                AppText(report.questionCount == 20 ? "每个维度由 4 题构成，满分 12 分后换算为百分制。分数越高，表示自述准备越充分。" : "这份旧版报告按原来的 15 题计算，每个维度 3 题，共 9 分。")
                    .font(.system(size: 10)).foregroundStyle(OracleTheme.muted).lineSpacing(5)
            }
        }
    }

    private var actionCard: some View {
        OracleCard {
            VStack(alignment: .leading, spacing: 18) {
                sectionTitle("给此刻的你", english: "NEXT SMALL STEP")
                AppText(report.recommendation).font(.system(size: 15, weight: .medium)).lineSpacing(7)
                HStack(alignment: .top, spacing: 12) {
                    AppText("01").font(.system(size: 11, design: .rounded)).foregroundStyle(OracleTheme.accent).padding(.top, 3)
                    AppText(report.weakest.dimension.action).font(.system(size: 13)).lineSpacing(6).foregroundStyle(OracleTheme.muted)
                }
                if report.needsPause || report.hasRiskFlag {
                    Label(L10n.t("先暂停，也是一种主动选择。"), systemImage: "pause.circle")
                        .font(.system(size: 11)).foregroundStyle(OracleTheme.sage)
                }
            }
        }
    }

    private var reflectionCard: some View {
        OracleCard {
            VStack(alignment: .leading, spacing: 15) {
                sectionTitle("留一句话给未来", english: "NOTE TO SELF")
                TextField(L10n.t("我准备先做的一件小事是……"), text: $reflection, axis: .vertical)
                    .font(.system(size: 14)).lineSpacing(6).lineLimit(3...6).focused($reflectionFocused)
                    .onChange(of: reflection) { _, text in
                        if text.count > 1000 { reflection = String(text.prefix(1000)) }
                        store.updateReflection(id: report.id, text: String(text.prefix(1000)))
                    }
                HStack {
                    AppText("自动保存 · 随时回来补充后来的故事")
                    Spacer()
                    Image(systemName: "pencil.line")
                }.font(.system(size: 10)).foregroundStyle(OracleTheme.muted)
            }
        }
    }

    private var answersCard: some View {
        OracleCard {
            DisclosureGroup(isExpanded: $showAnswers) {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(Array(DecisionQuestion.all.prefix(report.questionCount))) { question in
                        VStack(alignment: .leading, spacing: 8) {
                            AppText("\(question.id + 1). \(question.title.replacingOccurrences(of: "\n", with: ""))")
                                .font(.system(size: 13, weight: .medium))
                            if let answer = report.answers[question.id], question.options.indices.contains(answer) {
                                AppText(question.options[answer]).font(.system(size: 12)).foregroundStyle(OracleTheme.muted).lineSpacing(5)
                            }
                        }
                    }
                }.padding(.top, 20)
            } label: {
                AppText("回看我的回答").font(.system(size: 14, weight: .medium))
            }.tint(OracleTheme.sage)
        }
    }

    private func sectionTitle(_ title: String, english: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                AppText(title).font(.system(size: 16, weight: .semibold))
                Spacer()
                Eyebrow(text: english)
            }
            AppText(title).font(.system(size: 16, weight: .semibold))
        }
    }
}

import SwiftUI

struct QuestionFlowView: View {
    let store: DecisionStore
    let close: () -> Void
    let complete: (DecisionReport) -> Void
    @State private var draft: DecisionDraft
    @State private var showExit = false
    @State private var isReading = false
    @State private var showIncomplete = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(store: DecisionStore, initialDraft: DecisionDraft, close: @escaping () -> Void, complete: @escaping (DecisionReport) -> Void) {
        self.store = store
        self.close = close
        self.complete = complete
        _draft = State(initialValue: initialDraft)
    }

    private var question: DecisionQuestion { DecisionQuestion.all[draft.currentIndex] }
    private var answer: Int? { draft.answers[question.id] }

    var body: some View {
        VStack(spacing: 0) {
            if isReading {
                reading
            } else {
                header.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 22)
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 26) {
                            questionTitle.id("questionTop")
                            VStack(spacing: 12) {
                                ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                                    answerRow(index: index, text: option)
                                }
                            }
                            HStack(alignment: .top, spacing: 9) {
                                Image(systemName: "sparkle").foregroundStyle(OracleTheme.sage)
                                AppText("没有标准答案。选更接近真实的那个你。")
                                    .foregroundStyle(OracleTheme.muted)
                            }.font(.system(size: 11)).padding(.top, 4)
                        }
                        .frame(maxWidth: 540).frame(maxWidth: .infinity)
                        .padding(.horizontal, 24).padding(.bottom, 24)
                    }
                    .onChange(of: draft.currentIndex) { _, _ in proxy.scrollTo("questionTop", anchor: .top) }
                }
                footer
            }
        }
        .background(OracleTheme.background).foregroundStyle(OracleTheme.ink)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .confirmationDialog(L10n.t("把思考留在这里？"), isPresented: $showExit, titleVisibility: .visible) {
            Button(L10n.t("保存进度，稍后继续")) { save(); close() }
            Button(L10n.t("继续答题"), role: .cancel) {}
        } message: { AppText(L10n.f("已回答 %d 题，稍后可以继续。", draft.answers.count)) }
        .alert(L10n.t("还有问题未回答"), isPresented: $showIncomplete) {
            Button(L10n.t("返回检查")) { isReading = false }
        } message: { AppText("完整回答 20 个问题后才能生成决定签。") }
        .task(id: isReading) {
            guard isReading else { return }
            do { try await Task.sleep(for: .seconds(reduceMotion ? 0.1 : 1.4)) } catch { return }
            guard !Task.isCancelled else { return }
            if let report = store.finish(draft) { complete(report) } else { showIncomplete = true }
        }
    }

    private var header: some View {
        VStack(spacing: 23) {
            HStack {
                Button { showExit = true } label: {
                    Image(systemName: "xmark").font(.system(size: 16))
                        .frame(width: 42, height: 42).background(OracleTheme.card, in: Circle())
                }.accessibilityLabel(L10n.t("保存并退出"))
                Spacer()
                Eyebrow(text: "A MOMENT OF CLARITY", color: OracleTheme.muted)
                Spacer()
                AppText(String(format: "%02d / 20", draft.currentIndex + 1))
                    .font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(OracleTheme.accent)
            }
            HStack(spacing: 4) {
                ForEach(0..<DecisionQuestion.all.count) { index in
                    Capsule().fill(index <= draft.currentIndex ? OracleTheme.accent : OracleTheme.line).frame(height: 3)
                }
            }.accessibilityLabel(L10n.t("第 \(draft.currentIndex + 1) 题，共 20 题"))
        }
        .frame(maxWidth: 540).frame(maxWidth: .infinity)
    }

    private var questionTitle: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 8) {
                Image(systemName: question.dimension.symbol)
                AppText(question.dimension.rawValue)
                AppText("/  \(DecisionDimension.allCases.firstIndex(of: question.dimension)! + 1) OF 5").font(.system(size: 10, design: .rounded)).opacity(0.6)
            }
            .font(.system(size: 12, weight: .medium)).foregroundStyle(OracleTheme.sage)
            .padding(.horizontal, 13).padding(.vertical, 10)
            .background(OracleTheme.sage.opacity(0.08), in: Capsule())

            AppText(question.title).font(.system(size: 31, weight: .medium)).lineSpacing(9)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            AppText(L10n.code.hasPrefix("zh") ? question.note : "请根据你此刻的实际准备程度作答。这是自我观察，不是预测。").font(.system(size: 13)).lineSpacing(6).foregroundStyle(OracleTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Rectangle().fill(OracleTheme.line).frame(width: 18, height: 1)
                AppText(draft.title).font(.system(size: 11)).foregroundStyle(OracleTheme.muted).lineLimit(2)
            }.padding(.bottom, 3)
        }.id(question.id)
    }

    private func answerRow(index: Int, text: String) -> some View {
        let selected = answer == index
        return Button {
            draft.answers[question.id] = index
            save()
        } label: {
            HStack(spacing: 15) {
                AppText(["A", "B", "C", "D"][index])
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(selected ? OracleTheme.buttonInk : OracleTheme.muted)
                    .frame(width: 31, height: 31)
                    .background(selected ? OracleTheme.accent : OracleTheme.line.opacity(0.6), in: Circle())
                AppText(L10n.code.hasPrefix("zh") ? text : ["完全不符合", "不太符合", "比较符合", "完全符合"][index]).font(.system(size: 14, weight: selected ? .medium : .regular))
                    .lineSpacing(5).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if selected { Image(systemName: "checkmark").font(.system(size: 13, weight: .semibold)).foregroundStyle(OracleTheme.accent) }
            }
            .padding(16).frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(selected ? OracleTheme.accent.opacity(0.06) : OracleTheme.card, in: RoundedRectangle(cornerRadius: 19))
            .overlay(RoundedRectangle(cornerRadius: 19).stroke(selected ? OracleTheme.accent : OracleTheme.line, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 19))
        }
        .buttonStyle(.plain).accessibilityIdentifier("answer\(index)")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: selected)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            if draft.currentIndex > 0 {
                Button {
                    draft.currentIndex -= 1
                    save()
                } label: {
                    Image(systemName: "arrow.left").frame(width: 58, height: 58)
                        .background(OracleTheme.card, in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(OracleTheme.line))
                }.accessibilityLabel(L10n.t("上一题"))
            }
            PrimaryButton(title: draft.currentIndex == DecisionQuestion.all.count - 1 ? "生成我的决定签" : "下一问", symbol: "arrow.right", enabled: answer != nil) {
                if draft.currentIndex < DecisionQuestion.all.count - 1 {
                    draft.currentIndex += 1
                    save()
                } else {
                    isReading = true
                }
            }.accessibilityIdentifier("nextQuestion")
        }
        .frame(maxWidth: 540).frame(maxWidth: .infinity)
        .padding(.horizontal, 24).padding(.vertical, 16)
        .background(OracleTheme.background)
    }

    private var reading: some View {
        VStack(spacing: 22) {
            Spacer()
            OracleOrb().frame(width: 260, height: 260)
            Eyebrow(text: "CONNECTING THE DOTS", color: OracleTheme.accent)
            AppText("把心里的线索，\n慢慢连起来。")
                .font(.system(size: 28, weight: .medium)).lineSpacing(8).multilineTextAlignment(.center)
            ProgressView().tint(OracleTheme.accent).padding(.top, 10)
            Spacer()
            AppText("答案一直在你心里。").font(.system(size: 12)).foregroundStyle(OracleTheme.muted).padding(.bottom, 40)
        }.frame(maxWidth: .infinity)
    }

    private func save() { store.draft = draft; store.persist() }
}

import SwiftUI
import UIKit

struct LotteryView: View {
    let store: LotteryStore
    @State private var mode: DrawMode = .original
    @State private var emotion: DrawEmotion?
    @State private var armed = false
    @State private var drawing = false
    @State private var requestID = 0
    @State private var result: DrawRecord?
    @State private var showHistory = false
    @State private var showLibrary = false
    @State private var feedback = LotteryFeedback()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Eyebrow(text: "A MOMENT TO SETTLE", color: OracleTheme.accent)
                Spacer()
                Button { showHistory = true } label: { Label(L10n.t("我的签笺"), systemImage: "clock.arrow.circlepath").font(.system(size: 12)) }
            }
            HStack(spacing: 8) {
                ForEach(DrawMode.allCases) { item in
                    Button { mode = item; armed = false } label: {
                        VStack(spacing: 5) {
                            AppText(item.title).font(.system(size: 14, weight: .semibold))
                            AppText("100 签").font(.system(size: 10))
                        }.frame(maxWidth: .infinity).padding(.vertical, 13)
                            .foregroundStyle(mode == item ? OracleTheme.accent : OracleTheme.muted)
                            .background(mode == item ? OracleTheme.accent.opacity(0.1) : .clear, in: Capsule())
                    }.buttonStyle(.plain).disabled(drawing).accessibilityIdentifier("drawMode.\(item.rawValue)")
                        .accessibilityAddTraits(mode == item ? .isSelected : [])
                }
            }.padding(5).warmGlass(radius: 28)
            if mode == .guanyin {
                Button { showLibrary = true } label: { Label(L10n.t("浏览完整 100 签"), systemImage: "books.vertical") }
                    .font(.system(size: 12)).accessibilityIdentifier("openGuanyinLibrary")
            }
            AppText(mode == .original ? "摇一支签，\n安放此刻的心。" : "读一首旧诗，\n照见当下的心。")
                .font(.system(size: 33, weight: .medium)).lineSpacing(7)
            AppText("先选心情，再轻轻摇一摇。签里有意境，路在你脚下。")
                .font(.system(size: 13)).foregroundStyle(OracleTheme.muted).lineSpacing(5)
            HStack(spacing: 7) {
                ForEach(DrawEmotion.allCases) { item in
                    Button { emotion = item; armed = false } label: {
                        VStack(spacing: 9) {
                            Image(systemName: item.symbol).font(.system(size: 20, weight: .light))
                            AppText(item.rawValue).font(.system(size: 12, weight: .medium))
                        }.frame(maxWidth: .infinity).padding(.vertical, 15)
                            .foregroundStyle(emotion == item ? OracleTheme.buttonInk : OracleTheme.muted)
                            .background(emotion == item ? OracleTheme.accent : OracleTheme.card, in: RoundedRectangle(cornerRadius: 19))
                    }.buttonStyle(.plain).disabled(drawing)
                        .accessibilityIdentifier("emotion.\(item.rawValue)").accessibilityAddTraits(emotion == item ? .isSelected : [])
                }
            }
            AppText(emotion?.guidance ?? "你现在的感受是什么？五种心情都可以。")
                .font(.system(size: 13)).lineSpacing(6).foregroundStyle(OracleTheme.sage).frame(minHeight: 42, alignment: .top)
            ZStack {
                Circle().fill(OracleTheme.accent.opacity(0.045)).frame(width: 255, height: 255)
                BambooTube().frame(width: 165, height: 220)
                    .rotationEffect(.degrees(drawing && !reduceMotion ? 7 : -3))
                    .animation(drawing && !reduceMotion ? .easeInOut(duration: 0.12).repeatForever(autoreverses: true) : .default, value: drawing)
            }.frame(maxWidth: .infinity).frame(height: 270).accessibilityHidden(true)

            if armed {
                Label(L10n.t(drawing ? "签声轻响，片刻就好…" : "已准备好，请轻摇手机"), systemImage: "iphone.radiowaves.left.and.right")
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(OracleTheme.accent).frame(maxWidth: .infinity)
                PrimaryButton(title: drawing ? "正在抽签…" : "也可以点按抽一签", symbol: "sparkle", enabled: !drawing) { draw() }
                    .accessibilityIdentifier("drawLot")
            } else {
                PrimaryButton(title: "准备好了，开始摇签", symbol: "sparkle", enabled: emotion != nil) { armed = true }
                    .accessibilityIdentifier("armLottery")
            }
            AppText(mode == .original ? "100 首原创签诗 · 取意山水、竹月与灯火\n不分凶吉，不替你做决定。摇动不便时，可点按抽签。" : "七言通行版 · 传统签诗与现代解读分开阅读\n签的等第是传统称谓，不代表现实吉凶。可轻摇或点按。")
                .font(.system(size: 10)).lineSpacing(7).foregroundStyle(OracleTheme.muted).multilineTextAlignment(.center).frame(maxWidth: .infinity)
        }
        .foregroundStyle(OracleTheme.ink)
        .background(ShakeReceiver(enabled: armed && !drawing && result == nil) { draw() }.frame(width: 0, height: 0))
        .task(id: requestID) {
            guard drawing, scenePhase == .active, let emotion else { return }
            let activeRequest = requestID
            defer { if requestID == activeRequest { feedback.stop() } }
            feedback.start()
            guard !Task.isCancelled, drawing, scenePhase == .active else { return }
            do { try await Task.sleep(for: .seconds(LotteryFeedback.duration)) } catch { return }
            guard !Task.isCancelled, drawing, scenePhase == .active else { return }
            feedback.complete()
            result = store.draw(emotion: emotion, mode: mode)
            drawing = false
            armed = false
        }
        .onDisappear { drawing = false; armed = false; feedback.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { drawing = false; armed = false; feedback.stop() }
        }
        .sheet(isPresented: $showLibrary) { NavigationStack { GuanyinLibraryView().toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.t("完成")) { showLibrary = false } } } } }
        .sheet(item: $result) { LotResultView(record: $0) }
        .sheet(isPresented: $showHistory) {
            NavigationStack {
                List {
                    if store.records.isEmpty { AppText("还没有签笺。慢慢来，随时可以开始。").foregroundStyle(OracleTheme.muted) }
                    ForEach(store.records) { record in
                        NavigationLink { LotResultView(record: record) } label: {
                            VStack(alignment: .leading, spacing: 9) {
                                AppText("第\(record.lotID)签 · \(record.name)").font(.system(size: 16, weight: .medium))
                                AppText("\(record.mode.title) · \(record.emotion.rawValue) · \(record.date.formatted(.dateTime.month().day().hour().minute()))")
                                    .font(.system(size: 11)).foregroundStyle(OracleTheme.muted)
                            }.padding(.vertical, 7)
                        }.listRowBackground(OracleTheme.card)
                    }
                }.scrollContentBackground(.hidden).background(OracleTheme.background)
                    .navigationTitle(L10n.t("我的签笺")).navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.t("完成")) { showHistory = false } } }
            }.tint(OracleTheme.accent)
        }
    }
    private func draw() {
        guard armed, !drawing, emotion != nil, result == nil else { return }
        drawing = true
        requestID += 1
    }
}

private struct BambooTube: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach(0..<9) { index in
                RoundedRectangle(cornerRadius: 5)
                    .fill(LinearGradient(colors: [Color(hex: 0xE1BF86), Color(hex: 0xAE7B48)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 15, height: 175 + CGFloat(index % 3) * 12)
                    .overlay(alignment: .top) { Capsule().fill(OracleTheme.accent).frame(width: 12, height: 22).padding(.top, 6) }
                    .rotationEffect(.degrees(Double(index - 4) * 5), anchor: .bottom)
                    .offset(x: CGFloat(index - 4) * 10, y: -45)
            }
            RoundedRectangle(cornerRadius: 25)
                .fill(LinearGradient(colors: [Color(hex: 0xBA714A), Color(hex: 0x804831), Color(hex: 0xAC6543)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 142, height: 140)
                .overlay {
                    VStack(spacing: 4) {
                        AppText("问心").font(.system(size: 26, weight: .regular, design: .serif))
                        AppText("一签一念").font(.system(size: 9)).tracking(3)
                    }.foregroundStyle(Color(hex: 0xF5D8A7))
                }
                .overlay(RoundedRectangle(cornerRadius: 21).stroke(Color(hex: 0xE0B780).opacity(0.5)).padding(7))
                .shadow(color: OracleTheme.accent.opacity(0.15), radius: 18, y: 14)
        }
    }
}

struct LotResultView: View {
    let record: DrawRecord
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Eyebrow(text: "一签一念 / \(record.emotion.rawValue)", color: OracleTheme.accent)
                    VStack(spacing: 20) {
                        AppText("第 \(record.lotID) 签").font(.system(size: 12)).foregroundStyle(OracleTheme.muted)
                        AppText(record.name).font(.system(size: 31, weight: .medium, design: .serif))
                        AppText(record.poem).font(.system(size: 24, weight: .regular, design: .serif)).lineSpacing(13).tracking(6).multilineTextAlignment(.center)
                        if let traditional = record.guanyinLot {
                            AppText("\(traditional.rank) · \(traditional.palace)（传统等第）")
                                .font(.system(size: 12)).foregroundStyle(OracleTheme.accent)
                        }
                        AppText(record.mode == .original ? "自拟签文 · 取意传统意象" : "观音灵签 · 七言通行版").font(.system(size: 10)).foregroundStyle(OracleTheme.muted)
                    }.frame(maxWidth: .infinity).padding(.vertical, 28).warmGlass()
                    AppText("解签 · 给此刻的你").font(.system(size: 17, weight: .semibold))
                    AppText(record.interpretation).font(.system(size: 15)).lineSpacing(9).accessibilityIdentifier("lotInterpretation")
                    OracleCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(L10n.t("可以先做的一件小事"), systemImage: "leaf").font(.system(size: 14, weight: .medium)).foregroundStyle(OracleTheme.sage)
                            if let quote = record.smallAction?.quote {
                                AppText(quote).font(.system(size: 17, design: .serif)).lineSpacing(7)
                            }
                            AppText(record.nextStep).font(.system(size: 14)).lineSpacing(6)
                            if let action = record.smallAction, let source = action.source, let address = action.sourceURL, let url = URL(string: address) {
                                Link(source + " · 原文", destination: url).font(.system(size: 11))
                            }

                        }
                    }
                    if let traditional = record.guanyinLot { GuanyinReadingSections(lot: traditional) }
                    ShareLink(item: record.shareText) { Label(L10n.t("分享这份签意"), systemImage: "square.and.arrow.up").font(.system(size: 14)).frame(maxWidth: .infinity).padding(17).warmGlass() }
                    AppText("签文是文化与自我关照的灵感，不预言结果，也不决定你的价值。")
                        .font(.system(size: 10)).foregroundStyle(OracleTheme.muted).lineSpacing(5)
                }.padding(25)
            }.background(OracleTheme.background).foregroundStyle(OracleTheme.ink)
                .navigationTitle(L10n.t(record.mode.title)).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.t("完成")) { dismiss() } } }
        }.tint(OracleTheme.accent).presentationDragIndicator(.visible)
    }
}

private struct ShakeReceiver: UIViewControllerRepresentable {
    let enabled: Bool
    let action: () -> Void
    func makeUIViewController(context: Context) -> ShakeController { ShakeController() }
    func updateUIViewController(_ controller: ShakeController, context: Context) {
        controller.action = enabled ? action : nil
        if enabled { controller.becomeFirstResponder() } else { controller.resignFirstResponder() }
    }
    static func dismantleUIViewController(_ controller: ShakeController, coordinator: ()) { controller.action = nil; controller.resignFirstResponder() }
    final class ShakeController: UIViewController {
        var action: (() -> Void)?
        override var canBecomeFirstResponder: Bool { true }
        override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); if action != nil { becomeFirstResponder() } }
        override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            if motion == .motionShake { action?() } else { super.motionBegan(motion, with: event) }
        }
    }
}

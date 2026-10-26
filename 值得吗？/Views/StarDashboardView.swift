import SwiftUI
import Combine

struct StarDashboardView: View {
    let profile: UserProfile
    let latestReport: DecisionReport?
    let details: () -> Void
    let ask: () -> Void
    @State private var today = Date()
    @Environment(\.scenePhase) private var scenePhase
    private var reading: StarReading { StarReading(profile: profile, period: .day, date: today, latestReport: latestReport) }
    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            HStack(spacing: 14) {
                AppText(profile.zodiac.glyph).font(.system(size: 36, weight: .light))
                    .foregroundStyle(OracleTheme.accent).frame(width: 63, height: 63)
                    .background(OracleTheme.accent.opacity(0.09), in: Circle())
                VStack(alignment: .leading, spacing: 7) {
                    AppText(profile.nickname).font(.system(size: 18, weight: .semibold))
                    AppText("\(L10n.t(profile.zodiac.name)) · \(L10n.t(profile.birth.rhythm))")
                        .font(.system(size: 11)).foregroundStyle(OracleTheme.muted)
                }
                Spacer()
                AppText(today.formatted(.dateTime.month().day()))
                    .font(.system(size: 11)).foregroundStyle(OracleTheme.muted)
            }.padding(.top, 3)

            Button(action: details) {
                OracleCard {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack {
                            AppText("自己").font(.system(size: 21, weight: .semibold))
                            Spacer()
                            HStack(spacing: 3) { AppText("更多"); Image(systemName: "chevron.right") }
                                .font(.system(size: 11)).foregroundStyle(OracleTheme.muted)
                        }
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 12) {
                                AppText("今日心情").font(.system(size: 13, weight: .medium))
                                HStack(alignment: .firstTextBaseline, spacing: 3) {
                                    AppText("\(reading.overall)").font(.system(size: 55, weight: .medium, design: .rounded)).tracking(-2)
                                        .accessibilityIdentifier("todayStarScore")
                                    AppText("分").font(.system(size: 12))
                                }.foregroundStyle(OracleTheme.accent)
                                AppText(L10n.content(reading.summary, english: "A small pause can make room for a clearer next step. Notice what you need today.")).font(.system(size: 11)).lineSpacing(5).lineLimit(3)
                                    .foregroundStyle(OracleTheme.muted).multilineTextAlignment(.leading)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            HStack(alignment: .bottom, spacing: 9) {
                                ForEach([LifeArea.love, .wealth, .career, .study, .social]) { area in
                                    let value = reading.areaScores.first { $0.area == area }!.score
                                    VStack(spacing: 10) {
                                        ZStack(alignment: .bottom) {
                                            Capsule().fill(color(area).opacity(0.12))
                                            Capsule().fill(color(area).opacity(0.85)).frame(height: CGFloat(value) * 0.86)
                                        }.frame(width: 10, height: 86)
                                        AppText("\(value)").font(.system(size: 13, weight: .medium, design: .rounded))
                                        AppText(area.rawValue).font(.system(size: 10)).foregroundStyle(OracleTheme.muted)
                                    }.frame(width: 25).accessibilityElement(children: .ignore)
                                        .accessibilityLabel(L10n.t("\(area.rawValue) \(value) 分"))
                                }
                            }.padding(.top, 3)
                        }
                        AppText("当天娱乐指数 · 点此查看完整星笺").font(.system(size: 10)).foregroundStyle(OracleTheme.muted)
                    }
                }
            }.buttonStyle(.plain).accessibilityIdentifier("openStarDetails")

            VStack(alignment: .leading, spacing: 15) {
                Eyebrow(text: "TODAY, AT YOUR OWN PACE", color: OracleTheme.sage)
                AppText(L10n.t(reading.headline))
                    .font(.system(size: 28, weight: .medium)).lineSpacing(7)
                AppText("日子有起伏，选择可以慢一点。\n留一点时间，听见自己的声音。")
                    .font(.system(size: 13)).lineSpacing(7).foregroundStyle(OracleTheme.muted)
            }.padding(.top, 10)
            PrimaryButton(title: "有个决定，想问问自己", action: ask)
            HStack(spacing: 7) {
                Image(systemName: "sparkle")
                AppText("20 个问题 · 把心动整理成行动")
            }.font(.system(size: 11)).foregroundStyle(OracleTheme.muted).frame(maxWidth: .infinity)
        }.foregroundStyle(OracleTheme.ink)
            .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { today = $0 }
            .onChange(of: scenePhase) { _, phase in if phase == .active { today = .now } }
    }
    private func color(_ area: LifeArea) -> Color {
        switch area {
        case .love: Color(hex: 0xBA8283)
        case .wealth: Color(hex: 0xC0A165)
        case .career: Color(hex: 0x94A489)
        case .study: Color(hex: 0x8BA5AF)
        default: Color(hex: 0xAE96AB)
        }
    }
}

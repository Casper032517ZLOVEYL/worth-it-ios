import SwiftUI
import UIKit

enum OracleTheme {
    static let background = adaptive(0xF7F1E8, 0x24201D)
    static let card = adaptive(0xFFFCF7, 0x332D28)
    static let line = adaptive(0xDDD0C1, 0x55483E)
    static let ink = adaptive(0x44382E, 0xF5EBDD)
    static let muted = adaptive(0x857462, 0xBEAB99)
    static let accent = adaptive(0xA55E42, 0xDEA181)
    static let sage = adaptive(0x66795F, 0xADBE9C)
    static let buttonInk = adaptive(0xFFF9F0, 0x30241C)

    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255,
                           blue: CGFloat(value & 255) / 255, alpha: 1)
        })
    }
}

extension AppAppearance {
    var colorScheme: ColorScheme? {
        switch self { case .system: nil; case .light: .light; case .dark: .dark }
    }
}

struct WarmGlass: ViewModifier {
    var radius: CGFloat = 26
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            content.glassEffect(.regular.tint(OracleTheme.card.opacity(0.35)).interactive(), in: RoundedRectangle(cornerRadius: radius))
        } else {
            content.background(OracleTheme.card, in: RoundedRectangle(cornerRadius: radius))
                .overlay(RoundedRectangle(cornerRadius: radius).stroke(OracleTheme.line.opacity(0.7)))
        }
    }
}

extension View {
    func warmGlass(radius: CGFloat = 26) -> some View { modifier(WarmGlass(radius: radius)) }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255,
                  blue: Double(hex & 255) / 255, opacity: 1)
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color = OracleTheme.muted
    var body: some View {
        AppText(text).font(.system(size: 10, weight: .medium, design: .rounded))
            .tracking(1.3).foregroundStyle(color)
    }
}

struct PrimaryButton: View {
    let title: String
    var symbol = "arrow.up.right"
    var enabled = true
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                AppText(title).font(.system(size: 16, weight: .semibold))
                Spacer()
                Image(systemName: symbol).font(.system(size: 17, weight: .medium))
            }
            .foregroundStyle(enabled ? OracleTheme.buttonInk : OracleTheme.muted)
            .padding(.horizontal, 23).frame(minHeight: 58)
            .background(enabled ? OracleTheme.accent : OracleTheme.line, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain).disabled(!enabled)
    }
}

struct OracleCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content.padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(OracleTheme.card, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(OracleTheme.line, lineWidth: 1))
    }
}

/// A code-drawn orbital instrument: no remote assets or network required.
struct OracleOrb: View {
    var compact = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var started = Date()

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            TimelineView(.animation(minimumInterval: 1.0 / 24, paused: reduceMotion || scenePhase != .active)) { timeline in
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSince(started)
                let breath = sin(time * .pi / 4)
                let orbit = time * .pi / 9
                ZStack {
                    Circle().fill(OracleTheme.sage.opacity(0.09 + breath * 0.025)).blur(radius: 28).padding(size * 0.1)
                        .scaleEffect(1 + breath * 0.04)
                    Canvas { context, canvas in
                        let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
                        let radius = size * 0.43
                        for tick in 0..<72 {
                            let angle = Double(tick) * .pi / 36
                            let length = tick % 6 == 0 ? 8.0 : 3.0
                            let start = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                            let end = CGPoint(x: center.x + cos(angle) * (radius - length), y: center.y + sin(angle) * (radius - length))
                            var path = Path()
                            path.move(to: start)
                            path.addLine(to: end)
                            context.stroke(path, with: .color(OracleTheme.muted.opacity(tick % 6 == 0 ? 0.6 : 0.25)), lineWidth: 1)
                        }
                        var cross = Path()
                        cross.move(to: CGPoint(x: center.x, y: center.y - radius - 9))
                        cross.addLine(to: CGPoint(x: center.x, y: center.y + radius + 9))
                        cross.move(to: CGPoint(x: center.x - radius - 9, y: center.y))
                        cross.addLine(to: CGPoint(x: center.x + radius + 9, y: center.y))
                        context.stroke(cross, with: .color(OracleTheme.line), style: StrokeStyle(lineWidth: 0.5, dash: [2, 5]))
                    }
                    Circle().stroke(OracleTheme.line, lineWidth: 1).frame(width: size * 0.74, height: size * 0.74)
                    Circle()
                        .fill(RadialGradient(colors: [Color(hex: 0xFFE7C2), Color(hex: 0xE6BC8B), Color(hex: 0xBA8969), Color(hex: 0x7B5544)], center: .init(x: 0.3 + sin(time * 0.35) * 0.12, y: 0.22 + cos(time * 0.35) * 0.08), startRadius: 0, endRadius: size * 0.57))
                        .frame(width: size * 0.57, height: size * 0.57)
                        .overlay {
                            Circle().stroke(.white.opacity(0.2), lineWidth: 0.8).frame(width: size * 0.57, height: size * 0.57)
                        }
                        .overlay {
                            Circle().fill(RadialGradient(colors: [.white.opacity(0.32), .clear], center: .init(x: 0.35 + sin(time * 0.35) * 0.15, y: 0.25), startRadius: 0, endRadius: size * 0.3))
                        }
                        .shadow(color: OracleTheme.sage.opacity(0.1), radius: 28)
                        .scaleEffect(1 + breath * 0.025)
                        .offset(y: breath * size * 0.015)
                    Ellipse().stroke(OracleTheme.accent.opacity(0.8), lineWidth: 1)
                        .frame(width: size * 0.88, height: size * 0.28).rotationEffect(.degrees(-31 + sin(time * 0.25) * 13))
                    Ellipse().stroke(OracleTheme.sage.opacity(0.35), lineWidth: 0.7)
                        .frame(width: size * 0.78, height: size * 0.35).rotationEffect(.degrees(48 + time * 5))
                    Image(systemName: "asterisk")
                        .font(.system(size: size * 0.24, weight: .ultraLight))
                        .foregroundStyle(OracleTheme.background.opacity(0.8))
                        .rotationEffect(.degrees(time * 5))
                        .offset(y: breath * size * 0.015)
                    Circle().fill(OracleTheme.accent).frame(width: 8, height: 8)
                        .offset(x: cos(orbit + .pi) * size * 0.44, y: sin(orbit + .pi) * size * 0.14)
                        .rotationEffect(.degrees(-31 + sin(time * 0.25) * 13))
                    Image(systemName: "sparkle").font(.system(size: 13)).foregroundStyle(OracleTheme.accent)
                        .scaleEffect(1 + breath * 0.15)
                        .opacity(0.8 + breath * 0.2)
                        .offset(x: size * 0.34, y: -size * 0.31)
                    if !compact {
                        Eyebrow(text: "INTUITION", color: OracleTheme.sage).rotationEffect(.degrees(-90)).offset(x: -size * 0.52)
                        Eyebrow(text: "REASON", color: OracleTheme.accent).rotationEffect(.degrees(90)).offset(x: size * 0.52)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .accessibilityHidden(true)
    }
}

struct ScreenHeader: View {
    let title: String
    let subtitle: String
    let back: () -> Void
    var body: some View {
        HStack {
            Button(action: back) {
                Image(systemName: "arrow.left").font(.system(size: 18))
                    .frame(width: 44, height: 44)
                    .background(OracleTheme.card, in: Circle())
            }.accessibilityLabel(L10n.t("返回"))
            Spacer()
            VStack(spacing: 5) {
                AppText(title).font(.system(size: 14, weight: .medium))
                Eyebrow(text: subtitle)
            }
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .foregroundStyle(OracleTheme.ink)
    }
}

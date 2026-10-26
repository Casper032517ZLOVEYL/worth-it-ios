import Foundation
import Observation

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case system, zhHans = "zh-Hans", zhHant = "zh-Hant", en, ja, ko, es, fr, de, it, pt, ru, uk, ar, hi, bn, ur, ta, te, id, ms, vi, th, tr, fa, he, pl, nl, fil
    var id: String { rawValue }
    var nativeName: String {
        switch self {
        case .system: "跟随系统"; case .zhHans: "简体中文"; case .zhHant: "繁體中文"; case .en: "English"
        case .ja: "日本語"; case .ko: "한국어"; case .es: "Español"; case .fr: "Français"; case .de: "Deutsch"
        case .it: "Italiano"; case .pt: "Português"; case .ru: "Русский"; case .uk: "Українська"
        case .ar: "العربية"; case .hi: "हिन्दी"; case .bn: "বাংলা"; case .ur: "اردو"; case .ta: "தமிழ்"; case .te: "తెలుగు"
        case .id: "Bahasa Indonesia"; case .ms: "Bahasa Melayu"; case .vi: "Tiếng Việt"; case .th: "ไทย"
        case .tr: "Türkçe"; case .fa: "فارسی"; case .he: "עברית"; case .pl: "Polski"; case .nl: "Nederlands"; case .fil: "Filipino"
        }
    }
    var resolvedCode: String {
        guard self == .system else { return rawValue }
        for preference in Locale.preferredLanguages {
            if preference.hasPrefix("zh") { return preference.contains("Hant") || preference.contains("TW") || preference.contains("HK") ? "zh-Hant" : "zh-Hans" }
            if let language = Self.allCases.first(where: { $0 != .system && preference.hasPrefix($0.rawValue) }) { return language.rawValue }
        }
        return "en"
    }
    var isRTL: Bool { ["ar", "fa", "he", "ur"].contains(resolvedCode) }
}

@Observable final class AppLanguageState {
    static let shared = AppLanguageState()
    var language: AppLanguage = .system
}

enum L10n {
    static var code: String { AppLanguageState.shared.language.resolvedCode }
    private static let table: [String: [String: String]] = {
        guard let url = Bundle.main.url(forResource: "InterfaceTranslations", withExtension: "json"),
              let data = try? Data(contentsOf: url), let result = try? JSONDecoder().decode([String: [String: String]].self, from: data) else { return [:] }
        return result
    }()
    static func t(_ source: String) -> String {
        let language = code
        if language == "zh-Hans" { return source }
        if let value = table[source]?[language] { return value }
        if language == "zh-Hant" { return source.applyingTransform(StringTransform(rawValue: "Hans-Hant"), reverse: false) ?? source }
        if let value = table[source]?["en"] { return value }
        // User-entered names, titles, dates, and traditional poems remain verbatim.
        return source
    }
    static func f(_ source: String, _ values: CVarArg...) -> String {
        String(format: t(source), locale: Locale(identifier: code), arguments: values)
    }
    static func content(_ source: String, english: String) -> String { code.hasPrefix("zh") ? t(source) : english }
}

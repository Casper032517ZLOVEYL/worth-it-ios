import Foundation
import Observation

enum AccountMethod: String, Codable, CaseIterable, Identifiable {
    case local = "本机档案", phone = "手机号", email = "邮箱", wechat = "微信"
    var id: String { rawValue }
    var symbol: String {
        switch self { case .local: "iphone.gen3"; case .phone: "iphone"; case .email: "envelope"; case .wechat: "bubble.left.and.bubble.right" }
    }
    var placeholder: String {
        switch self { case .local: ""; case .phone: "请输入中国大陆手机号"; case .email: "name@example.com"; case .wechat: "请输入你的微信号" }
    }
    func normalized(_ value: String) -> String {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return self == .phone ? text.replacingOccurrences(of: " ", with: "") : text.lowercased()
    }
    func isValid(_ value: String) -> Bool {
        guard self != .wechat else { return false } // WeChat identities only come from the verified backend.
        if self == .local { return UUID(uuidString: value) != nil }
        let text = normalized(value)
        let pattern: String
        switch self {
        case .local: return false
        case .phone: pattern = "^1[3-9][0-9]{9}$"
        case .email: pattern = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        case .wechat: pattern = "^[a-zA-Z][a-zA-Z0-9_-]{5,19}$"
        }
        return text.range(of: pattern, options: .regularExpression) != nil
    }
    var formatHint: String {
        switch self {
        case .local: "无需手机号或邮箱，记录只保存在本机。"
        case .phone: "使用 11 位中国大陆手机号。"
        case .email: "使用完整邮箱地址，例如 name@example.com。"
        case .wechat: "6–20 位，字母开头，可含数字、下划线和减号。"
        }
    }
}

enum AppAppearance: String, Codable, CaseIterable, Identifiable {
    case system = "跟随系统", light = "浅色", dark = "深色"
    var id: String { rawValue }
    var symbol: String {
        switch self { case .system: "circle.lefthalf.filled"; case .light: "sun.max"; case .dark: "moon" }
    }
}

struct BirthDetails: Codable, Equatable {
    var year: Int
    var month: Int
    var day: Int
    var hour: Int?
    var minute: Int?
    var place: BirthPlace? = nil

    init(date: Date, includeTime: Bool, calendar: Calendar = .current) {
        year = calendar.component(.year, from: date)
        month = calendar.component(.month, from: date)
        day = calendar.component(.day, from: date)
        hour = includeTime ? calendar.component(.hour, from: date) : nil
        minute = includeTime ? calendar.component(.minute, from: date) : nil
    }
    var date: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour ?? 12, minute: minute ?? 0)) ?? .now
    }
    var label: String {
        let day = String(format: "%04d.%02d.%02d", year, month, self.day)
        guard let hour else { return day + " · 时间未知" }
        return day + String(format: " · %02d:%02d", hour, minute ?? 0)
    }
    var rhythm: String {
        guard let hour else { return "自在节律" }
        switch hour {
        case 5..<11: return "晨光慢启型"
        case 11..<17: return "午后生长型"
        case 17..<23: return "暮色漫游型"
        default: return "静夜灵感型"
        }
    }
    var seedKey: String { "\(year)-\(month)-\(day)-\(hour.map(String.init) ?? "unknown")-\(minute.map(String.init) ?? "unknown")" }
}

enum ZodiacSign: Int, CaseIterable, Codable {
    case aries, taurus, gemini, cancer, leo, virgo, libra, scorpio, sagittarius, capricorn, aquarius, pisces
    static func forBirthday(month: Int, day: Int) -> Self {
        let date = month * 100 + day
        return switch date {
        case 321...419: .aries
        case 420...520: .taurus
        case 521...621: .gemini
        case 622...722: .cancer
        case 723...822: .leo
        case 823...922: .virgo
        case 923...1023: .libra
        case 1024...1122: .scorpio
        case 1123...1221: .sagittarius
        case 120...218: .aquarius
        case 219...320: .pisces
        default: .capricorn
        }
    }
    var name: String { ["白羊座", "金牛座", "双子座", "巨蟹座", "狮子座", "处女座", "天秤座", "天蝎座", "射手座", "摩羯座", "水瓶座", "双鱼座"][rawValue] }
    var glyph: String { ["♈︎", "♉︎", "♊︎", "♋︎", "♌︎", "♍︎", "♎︎", "♏︎", "♐︎", "♑︎", "♒︎", "♓︎"][rawValue] }
    var element: String { ["火象", "土象", "风象", "水象"][rawValue % 4] }
    var mode: String { ["开创", "固定", "变动"][rawValue % 3] }
    var keywords: [String] {
        [["勇气", "直接", "行动"], ["耐心", "感官", "安定"], ["好奇", "表达", "灵活"],
         ["关怀", "敏感", "归属"], ["热忱", "创造", "自信"], ["细致", "秩序", "打磨"],
         ["平衡", "审美", "连接"], ["专注", "洞察", "深度"], ["探索", "自由", "乐观"],
         ["责任", "长线", "踏实"], ["独立", "新意", "理想"], ["想象", "共情", "温柔"]][rawValue]
    }
    var invitation: String {
        ["让勇气先迈一小步，也给自己留一点慢下来的余地。", "把舒服的日常当作起点，再为改变留一扇窗。", "好奇心可以带路，今天也试着把一件事做完。", "照顾别人的同时，把自己的需求也写进清单。",
         "让热情有一个出口，也允许自己偶尔不发光。", "细致是礼物，做到足够好时就可以先交给世界。", "在考虑所有人之前，先听见你自己的偏好。", "把专注留给值得的事，不必解读每一个沉默。",
         "远方很美，眼前一个小小的尝试也算出发。", "为长期目标努力时，也为今天留一点松弛。", "保留独特的想法，也给具体的感受一个位置。", "想象可以很远，照顾自己可以从此刻开始。"] [rawValue]
    }
}

struct UserProfile: Identifiable, Codable, Equatable {
    var id = UUID()
    var method: AccountMethod
    var identifier: String
    var nickname: String
    var birth: BirthDetails
    var createdAt = Date()
    var serverUserID: String?
    var isLocalOnly: Bool { method == .local || method == .email }
    var zodiac: ZodiacSign { .forBirthday(month: birth.month, day: birth.day) }
    var seedKey: String { "\(id.uuidString)|\(birth.seedKey)" }
    var signature: String { String(format: "%06X", StableSeed.hash(seedKey) & 0xFFFFFF) }
    var maskedIdentifier: String {
        switch method {
        case .local: return ""
        case .phone: return String(identifier.prefix(3)) + "****" + String(identifier.suffix(4))
        case .email:
            let parts = identifier.split(separator: "@")
            return String(identifier.prefix(1)) + "***@" + (parts.last.map(String.init) ?? "")
        case .wechat: return "已通过微信授权"
        }
    }
}

struct WeChatUser: Codable, Equatable {
    let id: String
    let nickname: String
    var phone: String? = nil
    var email: String? = nil
    var providers: [String]? = nil
    var hasPassword: Bool? = nil
}

@Observable final class AccountStore {
    private(set) var profiles: [UserProfile] = []
    private(set) var activeID: UUID?
    var language: AppLanguage = .system { didSet { AppLanguageState.shared.language = language; save() } }
    var appearance: AppAppearance = .system { didSet { save() } }
    private var completedTasks: Set<String> = []
    var error: String?
    private let defaults: UserDefaults
    private let key = "worthit.accounts.v1"
    private struct Archive: Codable {
        var profiles: [UserProfile]
        var activeID: UUID?
        var appearance: AppAppearance
        var language: AppLanguage?
        var completedTasks: Set<String>
    }
    var activeProfile: UserProfile? { profiles.first { $0.id == activeID } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        AppLanguageState.shared.language = .system
        guard let data = defaults.data(forKey: key) else { return }
        do {
            let archive = try JSONDecoder().decode(Archive.self, from: data)
            profiles = archive.profiles
            activeID = archive.activeID
            appearance = archive.appearance
            language = archive.language ?? .system
            AppLanguageState.shared.language = language
            completedTasks = archive.completedTasks
            if !profiles.isEmpty {
                defaults.set(true, forKey: "worthit.legacy.migrated")
                defaults.removeObject(forKey: "worthit.decisions.v1")
            }
        } catch { self.error = "本机档案暂时无法读取，请保留应用数据后重试。" }
    }

    func existing(method: AccountMethod, identifier: String) -> UserProfile? {
        profiles.first { $0.method == method && $0.identifier == method.normalized(identifier) }
    }

    @discardableResult func register(method: AccountMethod, identifier: String, nickname: String, birth: BirthDetails) -> Bool {
        guard (method == .email || method == .local), method.isValid(identifier), !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              (1900...Calendar.current.component(.year, from: .now)).contains(birth.year), birth.date <= .now else { return false }
        if let profile = existing(method: method, identifier: identifier) {
            activeID = profile.id
        } else {
            let profile = UserProfile(method: method, identifier: method.normalized(identifier), nickname: String(nickname.prefix(20)), birth: birth)
            migrateLegacy(to: profile.id)
            profiles.append(profile)
            activeID = profile.id
        }
        save()
        return true
    }

    func resume(_ profile: UserProfile) {
        guard profile.method == .email || profile.method == .local else { return }
        activeID = profile.id; save()
    }
    func resumeVerifiedWeChat(_ user: WeChatUser) -> Bool {
        guard let profile = profiles.first(where: { $0.serverUserID == user.id || ($0.method == .wechat && $0.identifier == user.id) }) else { return false }
        activeID = profile.id; save(); return true
    }
    func registerWeChat(_ user: WeChatUser, nickname: String, birth: BirthDetails) {
        guard !user.id.isEmpty, !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, birth.date <= .now else { return }
        if resumeVerifiedWeChat(user) { return }
        let profile = UserProfile(method: .wechat, identifier: user.id, nickname: String(nickname.prefix(20)), birth: birth, serverUserID: user.id)
        migrateLegacy(to: profile.id)
        profiles.append(profile); activeID = profile.id; save()
    }
    func resumeVerifiedPhone(_ user: WeChatUser) -> Bool {
        guard let phone = user.phone, AccountMethod.phone.isValid(phone),
              let index = profiles.firstIndex(where: { $0.serverUserID == user.id || ($0.method == .phone && $0.identifier == phone) }) else { return false }
        profiles[index].serverUserID = user.id
        if profiles[index].method == .phone { profiles[index].identifier = phone }
        activeID = profiles[index].id; save(); return true
    }
    func registerPhone(_ user: WeChatUser, nickname: String, birth: BirthDetails) {
        guard let phone = user.phone, AccountMethod.phone.isValid(phone), !user.id.isEmpty,
              !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, birth.date <= .now else { return }
        if resumeVerifiedPhone(user) { return }
        let profile = UserProfile(method: .phone, identifier: phone, nickname: String(nickname.prefix(20)), birth: birth, serverUserID: user.id)
        migrateLegacy(to: profile.id)
        profiles.append(profile); activeID = profile.id; save()
    }
    private func migrateLegacy(to id: UUID) {
        guard profiles.isEmpty, !defaults.bool(forKey: "worthit.legacy.migrated") else { return }
        if let legacy = defaults.data(forKey: "worthit.decisions.v1") {
            defaults.set(legacy, forKey: Self.decisionKey(id))
            defaults.removeObject(forKey: "worthit.decisions.v1")
        }
        defaults.set(true, forKey: "worthit.legacy.migrated")
    }
    func refreshVerifiedIdentity(_ user: WeChatUser) {
        guard let index = profiles.firstIndex(where: { $0.id == activeID }),
              profiles[index].serverUserID == user.id else { return }
        if profiles[index].method == .phone, let phone = user.phone { profiles[index].identifier = phone }
        save()
    }
    @MainActor func treeHoleStore(for profile: UserProfile) -> TreeHoleStore { TreeHoleStore(profileID: profile.id, defaults: defaults, canSave: { [weak self] in self?.profiles.contains(where: { $0.id == profile.id }) == true }) }
    func lotteryStore(for profile: UserProfile) -> LotteryStore { LotteryStore(profileID: profile.id, defaults: defaults) }
    func deleteActiveProfile() {
        guard let id = activeID else { return }
        defaults.removeObject(forKey: Self.decisionKey(id))
        defaults.removeObject(forKey: LotteryStore.key(id))
        defaults.removeObject(forKey: LotteryStore.actionKey(id))
        defaults.removeObject(forKey: "worthit.tree-hole.v1.\(id.uuidString)")
        completedTasks = completedTasks.filter { !$0.hasPrefix(id.uuidString + "|") }
        profiles.removeAll { $0.id == id }; activeID = nil; save()
    }
    func decisionStore(for profile: UserProfile) -> DecisionStore { DecisionStore(defaults: defaults, key: Self.decisionKey(profile.id)) }
    func signOut() { activeID = nil; save() }
    func update(nickname: String, birth: BirthDetails) {
        guard let index = profiles.firstIndex(where: { $0.id == activeID }), !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              birth.date <= .now else { return }
        profiles[index].nickname = String(nickname.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20))
        profiles[index].birth = birth
        save()
    }
    func isDone(_ taskID: String) -> Bool { completedTasks.contains(taskKey(taskID)) }
    func toggleTask(_ taskID: String) {
        let key = taskKey(taskID)
        if completedTasks.contains(key) { completedTasks.remove(key) } else { completedTasks.insert(key) }
        save()
    }
    private func taskKey(_ taskID: String) -> String { "\(activeID?.uuidString ?? "none")|\(taskID)" }
    static func decisionKey(_ id: UUID) -> String { "worthit.decisions.v1.\(id.uuidString)" }
    private func save() {
        do {
            let archive = Archive(profiles: profiles, activeID: activeID, appearance: appearance, language: language, completedTasks: completedTasks)
            defaults.set(try JSONEncoder().encode(archive), forKey: key)
        } catch { self.error = "档案保存未完成，请稍后重试。" }
    }
}

enum StableSeed {
    static func hash(_ text: String) -> UInt64 {
        text.utf8.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 }
    }
    static func index(_ text: String, count: Int) -> Int { Int(hash(text) % UInt64(count)) }
}

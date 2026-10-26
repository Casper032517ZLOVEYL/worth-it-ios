import Foundation
import Observation

enum DecisionCategory: String, Codable, CaseIterable, Identifiable {
    case career = "工作", relationship = "关系", money = "消费", life = "人生"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .career: "briefcase"
        case .relationship: "heart"
        case .money: "creditcard"
        case .life: "sparkles"
        }
    }
    var example: String {
        switch self {
        case .career: "比如：离开现在的工作，去做自由职业"
        case .relationship: "比如：和伴侣搬到同一个城市生活"
        case .money: "比如：用半年的积蓄买一辆车"
        case .life: "比如：去一个陌生的城市重新开始"
        }
    }
}

enum DecisionDimension: String, CaseIterable, Codable {
    case motivation = "动机清晰", evidence = "事实依据", resources = "资源准备"
    case risk = "风险承受", autonomy = "独立判断"

    var symbol: String {
        switch self {
        case .motivation: "flame"
        case .evidence: "magnifyingglass"
        case .resources: "square.stack.3d.up"
        case .risk: "shield.lefthalf.filled"
        case .autonomy: "safari"
        }
    }
    var action: String {
        switch self {
        case .motivation: "写下你真正想得到的东西，再写一个不做这件事也能接近它的办法。"
        case .evidence: "找一个经历过这件事的人聊聊，记录一条支持和一条反对的真实证据。"
        case .resources: "列出第一步需要的时间、钱和支持，确认哪些已经到位。"
        case .risk: "写下最坏的结果、可接受的损失上限，以及触发退出的具体条件。"
        case .autonomy: "暂时关掉外界的声音，隔一天再问自己：如果没人知道，我还会选它吗？"
        }
    }
}

struct DecisionQuestion: Identifiable {
    let id: Int
    let dimension: DecisionDimension
    let title: String
    let note: String
    /// Options are ordered from least to most prepared. Each contributes 0...3 points.
    let options: [String]

    static let currentVersion = 2
    static let legacyCount = 15
    static let all: [DecisionQuestion] = [
        .init(id: 0, dimension: .motivation, title: "这个念头，\n在你心里待了多久？", note: "突然的灵感很珍贵，反复想过的愿望也是。", options: ["刚刚冒出来，感觉特别强烈", "几天了，时不时会想起", "几个星期，认真琢磨过", "一个月以上，冷静时也想做"]),
        .init(id: 1, dimension: .motivation, title: "你最想通过它，\n改变什么？", note: "先分清你想奔向什么，还是想逃离什么。", options: ["说不清，只想立刻改变现状", "主要想摆脱眼下的不舒服", "有想要的结果，但还比较模糊", "目标具体，也符合我的长期方向"]),
        .init(id: 2, dimension: .motivation, title: "热情退去之后，\n你还愿意继续吗？", note: "想象一个平凡、疲惫、没有掌声的星期三。", options: ["可能不会，我靠感觉做事", "不确定，要看当时的心情", "愿意，但需要一些提醒和支持", "愿意，我接受过程中无聊的部分"]),
        .init(id: 3, dimension: .evidence, title: "你对这件事的了解，\n来自哪里？", note: "把想象中的生活，和实际的日常分开看。", options: ["直觉，或者几个令人心动的故事", "看过不少分享，还没有核实", "查过资料，也问过有经验的人", "亲自体验过，并核实了关键事实"]),
        .init(id: 4, dimension: .evidence, title: "如果有人反对，\n你能听进去吗？", note: "反对意见，也可能是帮你补全地图的线索。", options: ["不想听，我只需要一点鼓励", "能听，但觉得他们大概不懂", "会听，也愿意核实其中的顾虑", "已经主动找过反例，并调整了计划"]),
        .init(id: 5, dimension: .evidence, title: "除了这条路，\n你看过别的选择吗？", note: "别让眼前唯一的选项，伪装成最好的选项。", options: ["没有，就想做这一个", "想到过，但没有认真比较", "比较过其他方案的主要得失", "比较过，也考虑了暂时不行动"]),
        .init(id: 6, dimension: .resources, title: "开始所需要的资源，\n你准备了多少？", note: "资源包括钱、时间、技能，也包括愿意帮你的人。", options: ["还没算过，先开始再说", "大致知道，但缺口不小", "关键资源基本到位，还有小缺口", "已列出清单，关键资源都已落实"]),
        .init(id: 7, dimension: .resources, title: "你知道第一步，\n具体要做什么吗？", note: "一个能写进日历的动作，比一句决心更有力量。", options: ["还不知道从哪里开始", "有大方向，但没有具体动作", "知道第一步，还没安排时间", "动作、时间、完成标准都明确"]),
        .init(id: 8, dimension: .resources, title: "它会占用的时间，\n你真的留出来了吗？", note: "把它放进真实的生活，而不是理想的日程。", options: ["没有想过，应该挤得出来", "可能会和现有责任冲突", "调整过安排，基本能兼顾", "已经预留时间，也处理好了冲突"]),
        .init(id: 9, dimension: .risk, title: "如果结果不如预期，\n你承受得住吗？", note: "想一想具体的损失，而不只是一句“我不怕”。", options: ["可能会影响基本生活或重要责任", "代价有点超出我能承受的范围", "会难受，但基本生活有保障", "损失边界清楚，也留好了缓冲"]),
        .init(id: 10, dimension: .risk, title: "如果走不通，\n你有退路吗？", note: "留条退路，也是一种认真。", options: ["没有，也不想考虑失败", "有模糊的备选，还没确认", "有可执行的备选方案", "备选方案和止损条件都写清楚了"]),
        .init(id: 11, dimension: .risk, title: "能不能先用一个\n小尝试验证它？", note: "让现实给你一点反馈，再决定是否全力投入。", options: ["只想一次押上，不愿意小试", "也许可以，但还没想过怎么做", "设计了一个成本可控的小尝试", "已经小试过，并根据反馈做了调整"]),
        .init(id: 12, dimension: .autonomy, title: "如果没人知道，\n你还会做这件事吗？", note: "把掌声、比较和面子，暂时放到房间外面。", options: ["可能不会，被认可对我很重要", "不确定，别人的看法影响挺大", "大概会，它对我本身有价值", "会，这是我自己真正想要的"]),
        .init(id: 13, dimension: .autonomy, title: "现在的你，\n适合做这个决定吗？", note: "看看此刻的自己：睡眠、情绪，以及是否正被催促。", options: ["很激动或很低落，急着定下来", "有些疲惫或焦虑，想尽快结束纠结", "状态还算稳定，可以再想一想", "休息充分、情绪平稳，也没有被催促"]),
        .init(id: 14, dimension: .autonomy, title: "再等 48 小时，\n你的答案会改变吗？", note: "真正属于你的决定，通常经得起一点等待。", options: ["很可能会，我现在也拿不准", "可能会，我害怕错过这股劲头", "大概不会，但愿意留一点观察时间", "已经冷静等待过，答案依然一致"]),
        .init(id: 15, dimension: .motivation, title: "什么结果，\n才算值得你投入？", note: "把想要的感受，变成能辨认的目标。", options: ["只要和现在不同就好", "有期待，但不知道怎样算实现", "能说出主要目标，还没设定边界", "目标、取舍和不做的事都很清楚"]),
        .init(id: 16, dimension: .evidence, title: "什么新事实，\n会让你改变主意？", note: "愿意修正判断，也是一种笃定。", options: ["没有，谁也改变不了我", "没想过什么证据会影响决定", "知道几个需要核实的关键假设", "已写出关键假设及推翻它的证据"]),
        .init(id: 17, dimension: .resources, title: "遇到困难时，\n你能向谁求助？", note: "支持可以是一位朋友、一项技能或专业帮助。", options: ["没人能帮，也没有替代办法", "想得到人选，但还没联系", "有可联系的支持，仍需确认安排", "已经沟通过，支持和替代办法都落实"]),
        .init(id: 18, dimension: .risk, title: "什么时候，\n你会停下来重新评估？", note: "提前约定检查点，比事后硬撑更容易。", options: ["不论损失多少都继续", "出了问题再说，没有标准", "有大致的时间或损失上限", "已明确时间、损失上限和退出条件"]),
        .init(id: 19, dimension: .autonomy, title: "你是否可以\n自由地说“不”？", note: "留意期限、关系或承诺是否让你失去选择空间。", options: ["不能，我感到被强迫或威胁", "很难，主要担心让别人失望", "可以拒绝，但还需要表达边界", "可以，我能自主选择、拒绝或延期"])
    ]
}

struct DecisionDraft: Codable {
    var title: String
    var category: DecisionCategory
    var answers: [Int: Int] = [:]
    var currentIndex = 0
}

struct DimensionScore: Identifiable {
    let dimension: DecisionDimension
    let value: Int
    var id: String { dimension.rawValue }
}

struct DecisionReport: Identifiable, Codable {
    var id = UUID()
    let date: Date
    let title: String
    let category: DecisionCategory
    let answers: [Int: Int]
    var reflection: String = ""
    var questionnaireVersion: Int? = nil
    var questionCount: Int { questionnaireVersion == 2 || answers.keys.contains(where: { $0 >= 15 }) ? 20 : 15 }
    private var scoredQuestions: [DecisionQuestion] { Array(DecisionQuestion.all.prefix(questionCount)) }

    var dimensions: [DimensionScore] {
        DecisionDimension.allCases.map { dimension in
            let questions = scoredQuestions.filter { $0.dimension == dimension }
            let total = questions.reduce(0) { $0 + (answers[$1.id] ?? 0) }
            return DimensionScore(dimension: dimension, value: Int((Double(total) / Double(questions.count * 3) * 100).rounded()))
        }
    }
    var score: Int {
        Int((Double(scoredQuestions.reduce(0) { $0 + (answers[$1.id] ?? 0) }) / Double(questionCount * 3) * 100).rounded())
    }
    var weakest: DimensionScore { dimensions.min(by: { $0.value < $1.value })! }
    var hasRiskFlag: Bool { (answers[9] ?? 0) <= 1 }
    var needsPause: Bool { (answers[13] ?? 0) == 0 }
    var isPressured: Bool { questionCount == 20 && answers[19] == 0 }
    var archetype: String {
        if needsPause { return "情绪上头型" }
        if isPressured { return "需要缓冲型" }
        if hasRiskFlag { return "需要缓冲型" }
        if score >= 78 && weakest.value >= 56 { return "胸有成竹型" }
        if score >= 60 { return "蓄势待发型" }
        if score >= 35 { return "边走边想型" }
        return "心血来潮型"
    }
    var verdict: String {
        if isPressured { return "先把选择权，留回自己手里。" }
        if needsPause { return "先让情绪落地，再让决定发生。" }
        if hasRiskFlag { return "先给生活留好缓冲，再迈出这一步。" }
        if score >= 78 && weakest.value >= 56 { return "你的笃定，有迹可循。" }
        if score >= 60 { return "方向渐渐清晰，还差一点准备。" }
        if score >= 35 { return "念头有了，地图还需要补全。" }
        return "心动是真的，准备也要跟上。"
    }
    var recommendation: String {
        if isPressured { return "先暂停外界催促下的承诺，找可信赖的人讨论，确认你可以拒绝或延期。" }
        if needsPause { return "暂缓拍板。先休息、离开催促你的环境，等情绪平稳后再重新作答。" }
        if hasRiskFlag { return "暂缓高成本行动。你认为失败可能超出承受范围，先降低投入，保护基本生活和已有责任。" }
        if score >= 78 && weakest.value >= 56 { return "可以考虑从小规模行动开始。记录预期、设定检查点，用真实反馈校准接下来的投入。" }
        return "先补足「\(weakest.dimension.rawValue)」，再决定是否投入更多。你不需要今天就给未来一个最终答案。"
    }
    var shareText: String {
        "值得吗？｜我的决定签\n\(title)\n\(archetype) · 准备度 \(score)/100\n\(verdict)\n仅供自我梳理，分数不代表成功概率。"
    }
}

@Observable final class DecisionStore {
    var reports: [DecisionReport] = []
    var draft: DecisionDraft?
    var storageError: String?
    private let key: String
    private let defaults: UserDefaults

    private struct Archive: Codable {
        var reports: [DecisionReport]
        var draft: DecisionDraft?
    }

    init(defaults: UserDefaults = .standard, key: String = "worthit.decisions.v1") {
        self.key = key
        self.defaults = defaults
        guard let data = defaults.data(forKey: key) else { return }
        do {
            let archive = try JSONDecoder().decode(Archive.self, from: data)
            reports = archive.reports
            draft = archive.draft
        } catch {
            storageError = "本地记录暂时无法读取，原始数据已保留。"
        }
    }

    func clearHistory() {
        reports = []; draft = nil; persist()
    }

    func persist() {
        do {
            let data = try JSONEncoder().encode(Archive(reports: reports, draft: draft))
            defaults.set(data, forKey: key)
        } catch {
            storageError = "保存未完成，请暂时不要退出应用。"
        }
    }

    func finish(_ draft: DecisionDraft) -> DecisionReport? {
        guard DecisionQuestion.all.allSatisfy({ (0...3).contains(draft.answers[$0.id] ?? -1) }) else { return nil }
        let report = DecisionReport(date: .now, title: draft.title, category: draft.category, answers: draft.answers, questionnaireVersion: DecisionQuestion.currentVersion)
        reports.insert(report, at: 0)
        self.draft = nil
        persist()
        return report
    }

    func updateReflection(id: UUID, text: String) {
        guard let index = reports.firstIndex(where: { $0.id == id }) else { return }
        reports[index].reflection = text
        persist()
    }

    func delete(id: UUID) {
        reports.removeAll { $0.id == id }
        persist()
    }
}

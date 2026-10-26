import Foundation

enum ReadingPeriod: String, CaseIterable, Identifiable {
    case day = "日", week = "周", month = "月", year = "年"
    var id: String { rawValue }
    var title: String {
        switch self { case .day: "今日"; case .week: "本周"; case .month: "本月"; case .year: "今年" }
    }
    var unit: Calendar.Component {
        switch self { case .day: .day; case .week: .weekOfYear; case .month: .month; case .year: .year }
    }
}

enum LifeArea: String, CaseIterable, Identifiable {
    case love = "爱情", study = "学业", career = "事业", family = "家庭", wealth = "财运", social = "人际", mood = "情绪"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .love: "heart"; case .study: "book"; case .career: "briefcase"
        case .family: "house"; case .wealth: "leaf"; case .social: "person.2"; case .mood: "sun.haze"
        }
    }
    var dimension: DecisionDimension {
        switch self {
        case .love, .family, .social: .autonomy
        case .study, .career: .resources
        case .wealth: .risk
        case .mood: .motivation
        }
    }
    var titles: [String] {
        switch self {
        case .love: ["把想念说得具体一点", "靠近，也保留自己的空间", "被理解，从真实表达开始"]
        case .study: ["先完成一个小章节", "为好奇心留一页空白", "进步不必每次都很响亮"]
        case .career: ["把大目标拆成今天的一步", "让认真有一个落点", "慢一点，也能走得稳"]
        case .family: ["熟悉的人，也值得好好倾听", "把关心藏进一件小事", "家的温度，从一句问候开始"]
        case .wealth: ["留一点余裕给未来", "让心动先放进愿望清单", "分清想要，也看见已经拥有"]
        case .social: ["舒服的连接，不需要用力", "先倾听，再分享你的答案", "为关系留一点柔软"]
        case .mood: ["允许心情有自己的天气", "不必急着把自己调整好", "今天也可以温柔地慢下来"]
        }
    }
    var invitations: [String] {
        switch self {
        case .love: ["把“你应该懂我”换成一句具体的感受。如果你正独处，也可以把这份温柔留给自己。", "用一段不被手机打断的时间聊聊天；无需急着为关系下定义，先看看彼此是否自在。", "欣赏可以说出口，界限也可以。今天试着表达一个喜欢，再表达一个小小的需求。"]
        case .study: ["选一个最小的学习单元，专注二十分钟后做一次回顾。把不懂的地方记下来，比逼自己一口气学完更实际。", "遇到卡住的地方，换一种例子解释给自己听。把复杂问题拆开，不必用一次表现定义能力。", "为最需要动脑的任务留一个安静时段，结束时写下一个新发现，让反馈看得见。"]
        case .career: ["先确定一个可交付的小成果，再安排它的时间。事情多的时候，明确优先级比同时开很多头更有帮助。", "沟通前列出目的、边界和下一步。认真也需要被看见，你可以清楚地说出需要的资源。", "为正在推进的事情设一个检查点。收到反馈后再调整投入，不用一次就把所有事情做到完美。"]
        case .family: ["一条问候、一次一起吃饭，可能比完整的道理更容易被接住。关心别人时，也记得照顾自己的边界。", "如果有意见不同，先复述对方在意的事，再说你的想法。理解对方不等于必须同意。", "挑一件能一起完成的小事，让陪伴有一个具体的样子。你不需要独自承担所有人的情绪。"]
        case .wealth: ["整理一次近期收支，把需要和想要分开记录。消费前留一段等待时间；这里的分数不用于投资或收益判断。", "给愿望清单标上预算与优先级，看看哪些东西可以晚一点再买。数字只是娱乐提示，不表示获利机会。", "先照顾日常的稳定，再考虑额外支出。对任何投入核实事实，星座和幸运数字都不能替代实际判断。"]
        case .social: ["选择一段让你感到轻松的连接，发出一句真诚的问候。暂时没有精力社交，也可以礼貌地留一点空间。", "不急着从一条消息推测别人的心意。需要时多问一句，让事实替你减少猜测。", "把注意力放在交流本身，而不是是否表现得足够好。表达不同意见时，试着多用“我的感受是”。"]
        case .mood: ["先留意此刻身体的感觉，再为心情取一个名字。你可以等一等，不必在最急的时候做出重要决定。", "把能控制的一件小事写下来，剩下的暂时放到纸外。休息不需要先完成所有任务才能获得。", "给自己两分钟，看看窗外或喝几口水。如果这些小事没有帮助，也不用责怪自己。"]
        }
    }
}

struct AreaReading: Identifiable {
    let area: LifeArea
    let score: Int
    let title: String
    let text: String
    let basis: String
    var id: String { area.rawValue }
}

struct LuckyItem: Identifiable {
    let label: String
    let value: String
    let symbol: String
    var colorHex: UInt32?
    var id: String { label }
}

struct GentleTask: Identifiable {
    let id: String
    let title: String
    let detail: String
}

struct StarReading {
    let profile: UserProfile
    let period: ReadingPeriod
    let date: Date
    let latestReport: DecisionReport?
    let calendar: Calendar

    init(profile: UserProfile, period: ReadingPeriod, date: Date, latestReport: DecisionReport?, calendar: Calendar = .current) {
        self.profile = profile
        self.period = period
        self.date = date
        self.latestReport = latestReport
        var calendar = calendar
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        self.calendar = calendar
    }

    var interval: DateInterval { calendar.dateInterval(of: period.unit, for: date)! }
    var periodKey: String {
        let c = calendar.dateComponents([.year, .month, .day], from: interval.start)
        return "\(period.rawValue)|\(c.year!)-\(c.month!)-\(c.day!)"
    }
    var seed: String { profile.seedKey + "|" + periodKey }
    var rangeLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: L10n.code)
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        switch period {
        case .day: formatter.setLocalizedDateFormatFromTemplate("MMM d EEEE"); return formatter.string(from: date)
        case .month: formatter.setLocalizedDateFormatFromTemplate("yyyy MMM"); return formatter.string(from: date)
        case .year: formatter.setLocalizedDateFormatFromTemplate("yyyy"); return formatter.string(from: date)
        case .week:
            formatter.dateFormat = "M.d"
            return formatter.string(from: interval.start) + " — " + formatter.string(from: interval.end.addingTimeInterval(-1))
        }
    }
    var areaScores: [(area: LifeArea, score: Int)] {
        LifeArea.allCases.map { ($0, 56 + pick("score.\($0.rawValue)", count: 41)) }
    }
    var overall: Int { areaScores.reduce(0) { $0 + $1.score } / areaScores.count }
    var headline: String {
        ["把日子过成喜欢的温度", "让小小的笃定慢慢生长", "留一点空白，接住好心情", "按自己的节奏，轻轻出发", "今天的你，也值得被照顾"][pick("headline", count: 5)]
    }
    var summary: String {
        "\(profile.zodiac.invitation)\(period == .day ? "今天" : "这段时间")可以把注意力留给「\(LifeArea.allCases[pick("focus", count: 7)].rawValue)」，用一个小动作回应真实的生活。"
    }
    var suggestion: String { ["整理一角，给心留白", "慢慢吃饭，认真休息", "表达感受，走近自然", "分清轻重，先做一件", "记录灵感，照顾日常"][pick("suggest", count: 5)] }
    var avoid: String { ["在疲惫时急着拍板", "用别人的进度催促自己", "把猜测当作事实", "一次承担过多任务", "为了合群忽略感受"][pick("avoid", count: 5)] }

    var luckyItems: [LuckyItem] {
        let colors: [(String, UInt32)] = [("杏子橙", 0xDAA06B), ("鼠尾草绿", 0x8A9A7E), ("奶油黄", 0xDDC37C), ("玫瑰棕", 0xB78177), ("燕麦色", 0xB6A48B), ("雾蓝色", 0x8399AA), ("藕荷色", 0xAB90A6)]
        let color = colors[pick("color", count: colors.count)]
        let times = ["辰时 07–09", "巳时 09–11", "午时 11–13", "未时 13–15", "申时 15–17", "酉时 17–19"]
        let directions = ["东", "东南", "南", "西南", "西", "西北", "北", "东北"]
        let accessories = ["木质手链", "银色耳饰", "素色发夹", "编织手绳", "小巧胸针", "棉麻围巾", "细链项饰"]
        let foods = ["南瓜粥", "苹果", "一碗热面", "燕麦饼干", "烤红薯", "米饭团", "蔬菜汤"]
        let objects = ["小笔记本", "喜欢的书", "水杯", "柔软手帕", "一支铅笔", "帆布袋", "一张照片"]
        let plants = ["绿萝", "吊兰", "薄荷", "文竹", "琴叶榕", "迷迭香", "常春藤"]
        return [
            LuckyItem(label: "幸运颜色", value: color.0, symbol: "paintpalette", colorHex: color.1),
            LuckyItem(label: "幸运数字", value: "\(1 + pick("number", count: 99))", symbol: "number"),
            LuckyItem(label: "幸运时辰", value: times[pick("time", count: times.count)], symbol: "clock"),
            LuckyItem(label: "幸运方位", value: directions[pick("direction", count: directions.count)], symbol: "location.north"),
            LuckyItem(label: "幸运配饰", value: accessories[pick("accessory", count: accessories.count)], symbol: "sparkles"),
            LuckyItem(label: "幸运食物", value: foods[pick("food", count: foods.count)], symbol: "carrot"),
            LuckyItem(label: "幸运随身物", value: objects[pick("object", count: objects.count)], symbol: "bag"),
            LuckyItem(label: "幸运植物", value: plants[pick("plant", count: plants.count)], symbol: "leaf")
        ]
    }

    var visibleLuckyItems: [LuckyItem] {
        guard period != .day else { return luckyItems }
        let stones = ["月光石", "白水晶", "青金石", "玛瑙", "虎眼石", "萤石", "碧玉"]
        return Array(luckyItems.prefix(2)) + [LuckyItem(label: "幸运石", value: stones[pick("stone", count: stones.count)], symbol: "diamond")]
    }

    /// Original reflective copy. No planet transits or future events are inferred.
    var areaGuidance: [AreaReading] {
        [LifeArea.love, .wealth, .career, .study, .social].map { area in
            let index = pick("longcopy." + area.rawValue, count: area.invitations.count)
            let intro = "\(period.title)，把「\(profile.zodiac.keywords[area.dimension.rawValue.count % 3])」当作观察自己的一个角度。分数只是一点娱乐灵感，接下来发生什么，仍取决于真实的沟通与行动。"
            let practice: String
            switch area {
            case .love:
                practice = "独处时，可以先写下自己在关系中需要什么，不急着用一次相遇证明价值。有伴侣时，挑一个彼此都不赶时间的片刻，分享最近的感受，也听听对方的需要。相处中的小分歧可以具体讨论，不必上升成对整段关系的判断。"
            case .wealth:
                practice = "给这段时间的必要开支、可以等待的愿望和预留预算各留一栏。遇到心动的购买，先离开页面，过一阵再看。任何投资或借贷都需要核实信息、了解损失范围，不能根据这里的分数或幸运提示作决定。"
            case .career:
                practice = "把最想推进的工作拆成一个可以交付的小成果，并与相关的人确认标准。遇到分歧时，区分事实、假设和各自的需求，再商量下一步。如果手头任务太多，说明优先级和需要的支持，比默默承担更容易让合作顺畅。"
            case .study:
                practice = "为自己安排一次短而完整的学习：设定目标，尝试回忆，再核对遗漏。卡住的内容可以换一个例子，也可以向老师或同伴提一个具体问题。临近考试时，优先回顾错题与薄弱点；一次测验的表现不会决定你的能力。"
            default:
                practice = "把精力留给能让你自在的连接。对一条迟来的回复或一个表情，先不急着猜测含义；重要的事可以多问一句。没有精力应酬时，礼貌地说明自己的安排。清楚的边界和认真倾听，都能让交流少一点勉强。"
            }
            return AreaReading(area: area, score: areaScores.first { $0.area == area }!.score, title: area.rawValue, text: intro + "\n\n" + area.invitations[index] + "\n\n" + practice, basis: "\(period.title)自我观察 · \(rangeLabel)")
        }
    }

    /// Five cards rotate through all seven areas. Scores are decorative, independent of readiness.
    var interpretations: [AreaReading] {
        let offset = pick("areas", count: 7)
        return (0..<5).map { index in
            let area = LifeArea.allCases[(offset + index) % 7]
            let variant = pick("copy.\(area.rawValue)", count: area.titles.count)
            let basis: String
            let response: String
            if let report = latestReport, let value = report.dimensions.first(where: { $0.dimension == area.dimension })?.value {
                basis = "参考：\(report.date.formatted(.dateTime.month().day()))的答题 · \(area.dimension.rawValue) \(value)"
                if report.needsPause {
                    response = "你最近作答时提到状态较急或情绪强烈，重要决定先等一等。"
                } else if area == .wealth && report.hasRiskFlag {
                    response = "你在最近答题中表示损失可能难以承受，先保护基本生活和既有责任。"
                } else if value < 56 {
                    response = "最近的回答里，「\(area.dimension.rawValue)」还有准备空间，可以先从一个成本可控的小尝试开始。"
                } else {
                    response = "最近的回答显示，你在「\(area.dimension.rawValue)」上已有一些准备。用实际反馈确认它，不必仅凭感觉下结论。"
                }
            } else {
                basis = "灵感：\(profile.zodiac.name) · \(profile.birth.rhythm)"
                response = "还没有答题记录，这条内容只是一份星座主题的自我观察邀请。完成 20 问后，会加入你自己的回答线索。"
            }
            let opening = "以\(profile.zodiac.name)的「\(profile.zodiac.keywords[index % 3])」作一个温柔的提醒："
            let text = opening + area.invitations[variant] + "\n\n" + response
            let score = areaScores.first { $0.area == area }!.score
            return AreaReading(area: area, score: score, title: area.titles[variant], text: text, basis: basis)
        }
    }

    /// These always use the selected local calendar day, even while browsing week/month/year.
    var tasks: [GentleTask] {
        let ordinal = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        let personal = Int(StableSeed.hash(profile.seedKey) % 10000)
        let dayKey = calendar.dateComponents([.year, .month, .day], from: date)
        let key = "\(dayKey.year!)-\(dayKey.month!)-\(dayKey.day!)"
        return Self.taskBanks.enumerated().map { bankIndex, bank in
            let item = bank[(ordinal + personal + bankIndex * 3) % bank.count]
            return GentleTask(id: "\(key)|\(bankIndex)|\(item.0)", title: item.0, detail: item.1)
        }
    }
    private func pick(_ label: String, count: Int) -> Int { StableSeed.index(seed + "|" + label, count: count) }

    private static let taskBanks: [[(String, String)]] = [
        [("慢慢喝几口水", "放下手机，留意水的温度。约 1 分钟。"), ("看看窗外的远处", "把目光从屏幕移开，轻松看一会儿。"), ("为自己整理一小块桌面", "只收好三样东西，不必大扫除。"), ("听完一首喜欢的歌", "不切换页面，让这几分钟只属于你。"), ("摸一摸柔软的布料", "留意触感，把注意力带回此刻。"), ("给房间换一点新鲜空气", "条件合适时打开窗，站着休息一分钟。"), ("给一株植物看看土壤", "先观察，需要时再浇水。"), ("认真吃一小口食物", "在适合自己的饮食里，感受一次味道。")],
        [("轻轻转动肩膀", "坐稳或站稳，在舒服的范围内活动。"), ("离开座位走两分钟", "按身体舒服的方式走一小段，也可以坐着放松。"), ("放松一下紧绷的下巴", "自然呼吸，不用刻意改变节奏。"), ("把双脚稳稳放在地面", "感觉一下脚下的支撑，停留一分钟。"), ("给手腕和手指一点休息", "放下设备，轻轻伸展，感到不适就停止。"), ("走到光线柔和的地方", "不直视太阳，看看周围的颜色。"), ("把坐姿调整得舒服一点", "找到有支撑的位置，允许自己歇一会儿。"), ("按自己的节奏慢慢呼吸", "不用屏息，也不用追求标准次数。"), ("让双手离开键盘一分钟", "手掌放在腿上，什么也不用完成。")],
        [("写下此刻的一种感受", "只写一句，不评判它好不好。"), ("给待办事项删掉一件", "挑一件今天可以不做的事。"), ("记下一件已经做到的小事", "再小也可以，它已经发生了。"), ("把一个大问题拆成第一步", "只写那个最小、最容易开始的动作。"), ("给自己留一句宽松的话", "比如：我可以慢一点。"), ("把担心暂时放到纸上", "写下来，再挑出一件你能控制的小事。"), ("给明天留一个小期待", "一顿早餐、一首歌、一次短暂散步都算。"), ("把手机安静地放一会儿", "选择一个不会耽误必要联络的短时段。"), ("向信任的人问一声好", "不必展开长谈，一句就够。"), ("为今晚留十分钟空白", "不安排任务，按你的需要休息。")]
    ]
}

import Foundation

struct BirthPlace: Codable, Equatable {
    let name: String
    let latitude: Double
    let longitude: Double
    let timeZoneID: String
    var valid: Bool { !name.isEmpty && latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude) && TimeZone(identifier: timeZoneID) != nil }
    static let presets: [BirthPlace] = [
        .init(name: "北京", latitude: 39.9042, longitude: 116.4074, timeZoneID: "Asia/Shanghai"),
        .init(name: "上海", latitude: 31.2304, longitude: 121.4737, timeZoneID: "Asia/Shanghai"),
        .init(name: "广州", latitude: 23.1291, longitude: 113.2644, timeZoneID: "Asia/Shanghai"),
        .init(name: "深圳", latitude: 22.5431, longitude: 114.0579, timeZoneID: "Asia/Shanghai"),
        .init(name: "杭州", latitude: 30.2741, longitude: 120.1551, timeZoneID: "Asia/Shanghai"),
        .init(name: "成都", latitude: 30.5728, longitude: 104.0668, timeZoneID: "Asia/Shanghai"),
        .init(name: "重庆", latitude: 29.5630, longitude: 106.5516, timeZoneID: "Asia/Shanghai"),
        .init(name: "武汉", latitude: 30.5928, longitude: 114.3055, timeZoneID: "Asia/Shanghai"),
        .init(name: "西安", latitude: 34.3416, longitude: 108.9398, timeZoneID: "Asia/Shanghai"),
        .init(name: "南京", latitude: 32.0603, longitude: 118.7969, timeZoneID: "Asia/Shanghai"),
        .init(name: "香港", latitude: 22.3193, longitude: 114.1694, timeZoneID: "Asia/Hong_Kong"),
        .init(name: "台北", latitude: 25.0330, longitude: 121.5654, timeZoneID: "Asia/Taipei"),
        .init(name: "东京", latitude: 35.6762, longitude: 139.6503, timeZoneID: "Asia/Tokyo"),
        .init(name: "首尔", latitude: 37.5665, longitude: 126.9780, timeZoneID: "Asia/Seoul"),
        .init(name: "新加坡", latitude: 1.3521, longitude: 103.8198, timeZoneID: "Asia/Singapore"),
        .init(name: "曼谷", latitude: 13.7563, longitude: 100.5018, timeZoneID: "Asia/Bangkok"),
        .init(name: "悉尼", latitude: -33.8688, longitude: 151.2093, timeZoneID: "Australia/Sydney"),
        .init(name: "伦敦", latitude: 51.5074, longitude: -0.1278, timeZoneID: "Europe/London"),
        .init(name: "巴黎", latitude: 48.8566, longitude: 2.3522, timeZoneID: "Europe/Paris"),
        .init(name: "柏林", latitude: 52.5200, longitude: 13.4050, timeZoneID: "Europe/Berlin"),
        .init(name: "纽约", latitude: 40.7128, longitude: -74.0060, timeZoneID: "America/New_York"),
        .init(name: "洛杉矶", latitude: 34.0522, longitude: -118.2437, timeZoneID: "America/Los_Angeles"),
        .init(name: "温哥华", latitude: 49.2827, longitude: -123.1207, timeZoneID: "America/Vancouver"),
        .init(name: "圣保罗", latitude: -23.5505, longitude: -46.6333, timeZoneID: "America/Sao_Paulo"),
        .init(name: "迪拜", latitude: 25.2048, longitude: 55.2708, timeZoneID: "Asia/Dubai"),
        .init(name: "孟买", latitude: 19.0760, longitude: 72.8777, timeZoneID: "Asia/Kolkata")
    ]
}

struct NatalPlacement: Identifiable {
    let id: Int
    let name: String
    let glyph: String
    let longitude: Double
    let meaning: String
    let house: Int?
    var sign: ZodiacSign { ZodiacSign(rawValue: Int(longitude / 30) % 12)! }
    var degree: String { String(format: "%.1f°", longitude.truncatingRemainder(dividingBy: 30)) }
    var reading: String {
        let styles = ["倾向以直接尝试和表达需要来获得动力", "可能更重视稳定、耐心以及具体的感受", "可能喜欢交换信息、提问和探索不同角度", "可能更在意安全感、照顾与熟悉的连接", "可能通过创造、表达和获得回应感到有活力", "可能善于从细节、秩序和持续改进中找到方向", "可能留意公平、关系和不同立场之间的平衡", "可能偏好深入理解，谨慎地建立信任", "可能向往自由、学习与更宽阔的经验", "可能重视责任、现实条件与长期积累", "可能喜欢独立思考，以新的方式理解旧问题", "可能更容易被想象、共情与细腻的体验触动"]
        return "在传统占星的象征语言中，\(name)谈的是\(meaning)。落在\(sign.name)时，\(styles[sign.rawValue])。这是一种阅读视角，可以与你自己的经验对照，不是对人格的确定判断。\n\n可以问自己：什么时候我确实这样表现？什么时候完全不同？把符合的一点当作自我观察的入口，也保留那些不符合的部分。"
    }
}

struct NatalChart {
    let placements: [NatalPlacement]
    let note: String?
    static func calculate(_ birth: BirthDetails) -> NatalChart {
        guard let place = birth.place, place.valid, let hour = birth.hour, let minute = birth.minute,
              let zone = TimeZone(identifier: place.timeZoneID) else {
            return .init(placements: [], note: "补充准确的出生时间、出生地与当地时区后，可在本机计算星体、上升与整宫制宫位。时间未知时保留生日星座阅读，不生成个人星盘。")
        }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = zone
        guard let date = calendar.date(from: DateComponents(year: birth.year, month: birth.month, day: birth.day, hour: hour, minute: minute)),
              calendar.component(.hour, from: date) == hour, calendar.component(.minute, from: date) == minute,
              calendar.component(.day, from: date) == birth.day else {
            return .init(placements: [], note: "这个当地时间可能处于夏令时跳时区间，请核对出生记录后调整。")
        }
        var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let c = utc.dateComponents([.year,.month,.day,.hour,.minute], from: date)
        func longitude(_ body: Int) -> Double { WI_NatalLongitude(Int32(body), Int32(c.year!), Int32(c.month!), Int32(c.day!), Int32(c.hour!), Int32(c.minute!), place.latitude, place.longitude) }
        let asc = longitude(-1)
        let names = ["太阳", "月亮", "水星", "金星", "火星", "木星", "土星", "天王星", "海王星", "冥王星", "上升", "天顶"]
        let glyphs = ["☉", "☽", "☿", "♀", "♂", "♃", "♄", "♅", "♆", "♇", "ASC", "MC"]
        let meanings = ["表达意愿与自我认同", "感受、安定和内在需要", "思考、学习与交流", "欣赏、亲近与价值偏好", "行动、争取与边界", "探索、意义与成长", "责任、限制与长期练习", "独立、变化与创新", "想象、共情与理想", "深度、转变与掌控感", "面对新环境时的起点与呈现方式", "公共角色与发展方向"]
        let values = (0..<10).map { longitude($0) } + [asc, longitude(-2)]
        let placements = values.enumerated().compactMap { index, value -> NatalPlacement? in
            guard value.isFinite else { return nil }
            let house = asc.isFinite ? ((Int(value / 30) - Int(asc / 30) + 12) % 12 + 1) : nil
            return .init(id: index, name: names[index], glyph: glyphs[index], longitude: value, meaning: meanings[index], house: house)
        }
        return .init(placements: placements, note: abs(place.latitude) >= 66 ? "当前纬度接近极区，上升与宫位暂不计算；星体位置仍可阅读。" : nil)
    }
    static let houseMeanings = ["自我呈现、开始与面对环境的方式", "资源、日常价值与安全感", "交流、学习与近处的连接", "家、归属和私人空间", "创造、兴趣与表达喜悦", "日常安排、工作节奏与照顾", "一对一关系、协商与合作", "共享资源、信任与深层转变", "远方、学习与意义探索", "公共角色、事业方向与承担", "朋友、社群与共同愿景", "独处、内省与暂时退后一步"]
}

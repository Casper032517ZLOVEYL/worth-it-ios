import SwiftUI

struct ZodiacDetailView: View {
    let account: AccountStore
    let profile: UserProfile
    @State private var section = 0
    @State private var editBirth = false
    @State private var editPlace = false
    private var chart: NatalChart { NatalChart.calculate(profile.birth) }
    private var daily: StarReading { StarReading(profile: profile, period: .day, date: .now, latestReport: nil) }
    var body: some View {
        let computed = chart
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                ZodiacIdentityCard(birth: profile.birth)
                AppText("星座密码").font(.system(size: 21, weight: .semibold))
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 13) {
                    secret("表面上的自己", symbol: "person", value: computed.placements.first(where: { $0.name == "上升" }).map { $0.sign.keywords.joined(separator: " · ") } ?? "待补充出生资料", detail: "从面对新环境的方式开始观察。")
                    secret("内在的自己", symbol: "moon", value: computed.placements.first(where: { $0.name == "月亮" }).map { $0.sign.keywords.joined(separator: " · ") } ?? "待补充出生资料", detail: "留意什么让你感到安定与被理解。")
                    secret("可以发挥的长处", symbol: "sparkles", value: profile.zodiac.keywords.joined(separator: " · "), detail: "试着为这些词各找一个真实例子。")
                    secret("关系里的靠近", symbol: "heart", value: "尊重 · 表达 · 边界", detail: "合拍来自真实相处，不用星座判定缘分。")
                }
                OracleCard {
                    VStack(alignment: .leading, spacing: 13) {
                        AppText("给自己的今日提醒").font(.system(size: 16, weight: .semibold))
                        AppText(daily.suggestion + "。").font(.system(size: 14)).lineSpacing(7)
                        AppText("今天可以少一点：" + daily.avoid).font(.system(size: 12)).foregroundStyle(OracleTheme.muted).lineSpacing(6)
                        ForEach(daily.luckyItems.filter { ["幸运颜色", "幸运食物"].contains($0.label) }) { item in
                            HStack { AppText(item.label).foregroundStyle(OracleTheme.muted); Spacer(); AppText(item.value) }.font(.system(size: 13))
                        }
                        AppText("提醒与幸运提示仅供娱乐，不是个人运势预测。").font(.system(size: 10)).foregroundStyle(OracleTheme.muted)
                    }
                }
                birthSummary
                if let note = computed.note { AppText(note).font(.system(size: 12)).lineSpacing(7).foregroundStyle(OracleTheme.muted) }
                if !computed.placements.isEmpty {
                    NatalWheel(placements: computed.placements).frame(height: 280).accessibilityLabel("本机计算的星体位置示意")
                }
                Picker(L10n.t("解读内容"), selection: $section) { AppText("星座").tag(0); AppText("宫位").tag(1) }.pickerStyle(.segmented).accessibilityIdentifier("zodiac.segment")
                if section == 0 {
                    if computed.placements.isEmpty {
                        OracleCard {
                            VStack(alignment: .leading, spacing: 14) {
                                AppText("生日星座 · " + profile.zodiac.name).font(.system(size: 19, weight: .medium))
                                AppText(profile.zodiac.invitation).lineSpacing(7)
                                AppText("当前根据生日区间匹配，并非精确太阳黄经。临近交界日时，补全出生资料后以计算结果为准。").font(.system(size: 12)).foregroundStyle(OracleTheme.muted)
                            }
                        }
                    }
                    ForEach(computed.placements) { placement in
                        OracleCard {
                            VStack(alignment: .leading, spacing: 13) {
                                HStack { Text(verbatim: placement.glyph).foregroundStyle(OracleTheme.accent); AppText(placement.name + " · " + placement.sign.name).font(.system(size: 18, weight: .semibold)); Spacer(); Text(verbatim: placement.degree).font(.system(size: 12)).foregroundStyle(OracleTheme.muted) }
                                AppText(placement.meaning).font(.system(size: 12)).foregroundStyle(OracleTheme.muted)
                                DisclosureGroup(L10n.t("展开解读")) { AppText(placement.reading).font(.system(size: 14)).lineSpacing(8).padding(.top, 12) }
                            }
                        }.accessibilityIdentifier("zodiac.placement.\(placement.id)")
                    }
                    OracleCard { VStack(alignment: .leading, spacing: 12) { AppText("婚神星").font(.system(size: 17, weight: .semibold)); AppText("婚神星属于小行星。本版尚未接入对应星历，暂不显示你的落座或宫位，也不推断未来伴侣。").font(.system(size: 12)).lineSpacing(7) } }
                } else {
                    ForEach(0..<12, id: \.self) { house in
                        OracleCard {
                            VStack(alignment: .leading, spacing: 13) {
                                AppText("第 \(house + 1) 宫").font(.system(size: 19, weight: .medium))
                                AppText(NatalChart.houseMeanings[house]).font(.system(size: 13)).lineSpacing(6).foregroundStyle(OracleTheme.muted)
                                let occupants = computed.placements.filter { $0.id < 10 && $0.house == house + 1 }
                                if computed.placements.first(where: { $0.id == 10 }) != nil {
                                    AppText(occupants.isEmpty ? "本宫没有本版收录的主要星体。空宫不代表这一领域缺失。" : occupants.map { $0.name + " · " + $0.sign.name }.joined(separator: "\n")).font(.system(size: 14)).lineSpacing(6)
                                } else { AppText("补全出生资料后显示个人宫位。").font(.system(size: 12)) }
                            }
                        }
                    }
                }
                methodNote
                ShareLink(item: "值得吗？ · 我的星座阅读\n\(profile.zodiac.name) · \(profile.zodiac.keywords.joined(separator: "、"))\n\(profile.zodiac.invitation)\n星座是文化阅读的视角，真实的你由自己定义。") { Label(L10n.t("分享星座阅读"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity).padding(16).warmGlass() }
            }.frame(maxWidth: 540).frame(maxWidth: .infinity).padding(24)
        }.background(OracleTheme.background).foregroundStyle(OracleTheme.ink)
            .navigationTitle(L10n.t("我的星座档案")).navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
            .sheet(isPresented: $editBirth) { EditProfileView(account: account, profile: profile) }
            .sheet(isPresented: $editPlace) { BirthPlaceView(account: account, profile: profile) }
    }
    private var birthSummary: some View {
        OracleCard {
            VStack(alignment: .leading, spacing: 15) {
                AppText("出生资料").font(.system(size: 17, weight: .semibold))
                Button { editBirth = true } label: { HStack { AppText(profile.birth.label); Spacer(); Image(systemName: "pencil") }.font(.system(size: 13)) }.accessibilityIdentifier("zodiac.editTime")
                Button { editPlace = true } label: { HStack { AppText(profile.birth.place?.name ?? "补充出生地与时区"); Spacer(); Image(systemName: "globe.asia.australia") }.font(.system(size: 13)) }.accessibilityIdentifier("zodiac.editPlace")
                if let place = profile.birth.place { Text(verbatim: "\(place.latitude.formatted())°, \(place.longitude.formatted())° · \(place.timeZoneID)").font(.system(size: 10)).foregroundStyle(OracleTheme.muted) }
            }
        }
    }
    private var methodNote: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppText("计算与阅读说明").font(.system(size: 16, weight: .semibold))
            AppText("星体位置使用 Astronomy Engine 在本机计算：地心视位置、热带黄道；宫位采用整宫制，与录屏中的其他宫制可能不同。时区采用系统时区资料，夏令时重叠时刻取首次出现；接近极区时暂不计算上升与宫位。出生时间不确定时，结果也会随之不确定。")
            AppText("天体位置计算不代表占星解读经过科学验证。以下文字仅作文化阅读与自我观察，不是心理测评或现实结果预测。出生地只保存在本机，不请求定位权限。")
            NavigationLink { ContentSourcesView() } label: { Label(L10n.t("版本与来源"), systemImage: "books.vertical") }
        }.font(.system(size: 11)).lineSpacing(6).foregroundStyle(OracleTheme.muted)
    }
    private func secret(_ title: String, symbol: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Label(L10n.t(title), systemImage: symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(OracleTheme.accent)
            AppText(value).font(.system(size: 15, weight: .medium)).lineSpacing(4)
            AppText(detail).font(.system(size: 10)).lineSpacing(5).foregroundStyle(OracleTheme.muted)
        }.frame(maxWidth: .infinity, minHeight: 123, alignment: .topLeading).padding(16).background(OracleTheme.card, in: RoundedRectangle(cornerRadius: 21))
    }
}

private struct NatalWheel: View {
    let placements: [NatalPlacement]
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            ZStack {
                Circle().stroke(OracleTheme.line, lineWidth: 1).frame(width: size - 15, height: size - 15)
                Circle().stroke(OracleTheme.line, lineWidth: 1).frame(width: size * 0.65, height: size * 0.65)
                ForEach(0..<12, id: \.self) { i in
                    let angle = Double(i) * .pi / 6 - .pi
                    Text(verbatim: ZodiacSign(rawValue: i)!.glyph).font(.system(size: 18)).foregroundStyle(OracleTheme.sage)
                        .position(x: center.x + cos(angle + .pi/12) * size * 0.41, y: center.y + sin(angle + .pi/12) * size * 0.41)
                }
                ForEach(placements.filter { $0.id < 10 }) { p in
                    let angle = p.longitude * .pi / 180 - .pi
                    // Separate radial lanes keep close conjunctions distinct without shifting their longitude.
                    let radius = size * (0.15 + Double(p.id) * 0.016)
                    Text(verbatim: p.glyph).font(.system(size: 15)).foregroundStyle(OracleTheme.accent)
                        .position(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                }
                AppText("星体位置").font(.system(size: 9)).foregroundStyle(OracleTheme.muted).position(x: center.x, y: center.y + size * 0.31)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct BirthPlaceView: View {
    let account: AccountStore
    let profile: UserProfile
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var latitude: String
    @State private var longitude: String
    @State private var zone: String
    @State private var search = ""
    init(account: AccountStore, profile: UserProfile) {
        self.account = account; self.profile = profile
        _name = State(initialValue: profile.birth.place?.name ?? "")
        _latitude = State(initialValue: profile.birth.place.map { String($0.latitude) } ?? "")
        _longitude = State(initialValue: profile.birth.place.map { String($0.longitude) } ?? "")
        _zone = State(initialValue: profile.birth.place?.timeZoneID ?? "Asia/Shanghai")
    }
    private var place: BirthPlace? {
        guard let lat = Double(latitude), let lon = Double(longitude) else { return nil }
        let value = BirthPlace(name: name.trimmingCharacters(in: .whitespacesAndNewlines), latitude: lat, longitude: lon, timeZoneID: zone)
        return value.valid ? value : nil
    }
    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.t("选择常用城市")) {
                    TextField(L10n.t("搜索城市"), text: $search).accessibilityIdentifier("birthPlace.search")
                    ForEach(BirthPlace.presets.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }, id: \.name) { p in
                        Button { name = p.name; latitude = String(p.latitude); longitude = String(p.longitude); zone = p.timeZoneID } label: {
                            HStack { AppText(p.name); Spacer(); if name == p.name { Image(systemName: "checkmark") } }
                        }.accessibilityIdentifier("birthPlace.city.\(p.name)")
                    }
                }
                Section(L10n.t("或手动填写全球地点")) {
                    TextField(L10n.t("地点名称"), text: $name)
                    TextField(L10n.t("纬度：南负北正，-90 至 90"), text: $latitude).keyboardType(.numbersAndPunctuation)
                    TextField(L10n.t("经度：西负东正，-180 至 180"), text: $longitude).keyboardType(.numbersAndPunctuation)
                    NavigationLink { List(TimeZone.knownTimeZoneIdentifiers, id: \.self) { id in Button { zone = id } label: { HStack { Text(verbatim: id); Spacer(); if zone == id { Image(systemName: "checkmark") } } } }.navigationTitle(L10n.t("出生地时区")) } label: { VStack(alignment: .leading) { AppText("出生地时区"); Text(verbatim: zone).font(.footnote) } }
                }
                Section {
                    Button(L10n.t("保存出生地")) { if let place { var birth = profile.birth; birth.place = place; account.update(nickname: profile.nickname, birth: birth); dismiss() } }.disabled(place == nil).accessibilityIdentifier("birthPlace.save")
                    if profile.birth.place != nil { Button(L10n.t("移除出生地"), role: .destructive) { var birth = profile.birth; birth.place = nil; account.update(nickname: profile.nickname, birth: birth); dismiss() } }
                } footer: { AppText("选择出生城市及其当地时区；填写的是出生记录上的当地时间。城市中心坐标用于近似，若需更精确可手动修改。资料只在本机计算，随档案删除。") }
            }.scrollContentBackground(.hidden).background(OracleTheme.background).navigationTitle(L10n.t("出生地与时区"))
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.t("取消")) { dismiss() } } }
        }.tint(OracleTheme.accent)
    }
}

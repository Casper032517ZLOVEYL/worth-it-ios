import SwiftUI
import Combine

struct StarHomeView: View {
    let profile: UserProfile
    let account: AccountStore
    let latestReport: DecisionReport?
    let ask: () -> Void
    @State private var period: ReadingPeriod = .day
    @State private var selectedDate = Date()
    @State private var followsToday = true
    @State private var showCalendar = false
    @State private var calendarDate = Date()
    @State private var selectedInterpretation: AreaReading?
    @Environment(\.scenePhase) private var scenePhase
    private var reading: StarReading { StarReading(profile: profile, period: period, date: selectedDate, latestReport: latestReport) }

    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            greeting
            periodPicker
            dateNavigation
            if period == .day { weekStrip }
            scoreCard
            invitationCard
            luckyCard
            if period == .day { tasksCard }
            if period != .day { detailedAreas }
            interpretations
            AppText("星笺分数与幸运提示仅供娱乐，不是预测或心理诊断。食物与物品按个人需要选择，无需购买，也不表示真实吉凶。")
                .font(.system(size: 10)).foregroundStyle(OracleTheme.muted).lineSpacing(5)
        }
        .foregroundStyle(OracleTheme.ink)
        .sheet(isPresented: $showCalendar) {
            NavigationStack {
                VStack(spacing: 25) {
                    DatePicker(L10n.t("选择星笺日期"), selection: $calendarDate, displayedComponents: .date)
                        .datePickerStyle(.graphical).tint(OracleTheme.accent)
                    PrimaryButton(title: "查看这一天") { selectedDate = calendarDate; followsToday = reading.calendar.isDateInToday(calendarDate); showCalendar = false }
                }.padding(26).background(OracleTheme.background)
                    .navigationTitle(L10n.t("选择日期")).navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.t("取消")) { showCalendar = false } } }
            }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedInterpretation) { item in
            InterpretationDetail(item: item, period: period, rangeLabel: reading.rangeLabel)
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { date in
            if followsToday { selectedDate = date }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active && followsToday { selectedDate = .now } }
    }

    private var greeting: some View {
        HStack(alignment: .center, spacing: 15) {
            VStack(alignment: .leading, spacing: 11) {
                Eyebrow(text: "A LITTLE LIGHT FOR YOUR DAY", color: OracleTheme.accent)
                AppText("\(profile.nickname) · \(L10n.t(period.rawValue))")
                    .font(.system(size: 29, weight: .medium)).minimumScaleFactor(0.75).lineLimit(1)
                HStack(spacing: 7) {
                    AppText(profile.zodiac.name)
                    AppText("·")
                    AppText(profile.birth.rhythm)
                }.font(.system(size: 12)).foregroundStyle(OracleTheme.muted)
            }
            Spacer(minLength: 0)
            AppText(profile.zodiac.glyph).font(.system(size: 43, weight: .light))
                .foregroundStyle(OracleTheme.accent).frame(width: 70, height: 78)
                .background(OracleTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 26))
        }
    }

    private var periodPicker: some View {
        HStack(spacing: 5) {
            ForEach(ReadingPeriod.allCases) { item in
                Button { period = item } label: {
                    AppText(item.rawValue).font(.system(size: 15, weight: period == item ? .semibold : .regular))
                        .frame(maxWidth: .infinity).frame(height: 41)
                        .foregroundStyle(period == item ? OracleTheme.accent : OracleTheme.muted)
                        .background(period == item ? OracleTheme.accent.opacity(0.12) : .clear, in: Capsule())
                }.buttonStyle(.plain).accessibilityIdentifier("readingPeriod.\(item.rawValue)")
                    .accessibilityAddTraits(period == item ? .isSelected : [])
            }
        }.padding(5).warmGlass(radius: 28)
    }

    private var dateNavigation: some View {
        HStack {
            Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 32, height: 34) }
                .accessibilityLabel(L10n.t("上一个\(period.rawValue)")).accessibilityIdentifier("previousReadingDate")
            Spacer(minLength: 4)
            Button { calendarDate = selectedDate; showCalendar = true } label: {
                Label(reading.rangeLabel, systemImage: "calendar").font(.system(size: 12, weight: .medium))
            }.accessibilityIdentifier("readingDateLabel")
            Spacer(minLength: 4)
            Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 32, height: 34) }
                .accessibilityLabel(L10n.t("下一个\(period.rawValue)")).accessibilityIdentifier("nextReadingDate")
            if !followsToday {
                Button(L10n.t("今天")) { selectedDate = .now; followsToday = true }
                    .font(.system(size: 11)).padding(.horizontal, 9).padding(.vertical, 7)
                    .background(OracleTheme.accent.opacity(0.09), in: Capsule())
            }
        }.foregroundStyle(OracleTheme.muted).padding(.vertical, -8)
    }

    private var weekStrip: some View {
        let calendar = reading.calendar
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)!.start
        return HStack(spacing: 4) {
            ForEach(0..<7) { index in
                let date = calendar.date(byAdding: .day, value: index, to: start)!
                let selected = calendar.isDate(date, inSameDayAs: selectedDate)
                Button { selectedDate = date; followsToday = calendar.isDateInToday(date) } label: {
                    VStack(spacing: 9) {
                        AppText(calendar.veryShortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]).font(.system(size: 10))
                        AppText(calendar.isDateInToday(date) ? "今" : "\(calendar.component(.day, from: date))")
                            .font(.system(size: 14, weight: selected ? .semibold : .regular))
                    }.foregroundStyle(selected ? OracleTheme.buttonInk : OracleTheme.muted)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(selected ? OracleTheme.accent : .clear, in: Capsule())
                }.buttonStyle(.plain)
                    .accessibilityLabel(date.formatted(.dateTime.month().day().weekday()))
                    .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var scoreCard: some View {
        OracleCard {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .bottom, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        AppText("综合分数").font(.system(size: 13, weight: .medium))
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            AppText("\(reading.overall)").font(.system(size: 55, weight: .light, design: .rounded)).tracking(-3)
                                .accessibilityIdentifier("overallStarScore")
                            AppText("分").font(.system(size: 12))
                        }.foregroundStyle(OracleTheme.accent)
                    }
                    Spacer(minLength: 0)
                    HStack(alignment: .bottom, spacing: 9) {
                        ForEach([LifeArea.love, .wealth, .career, .study, .social]) { area in
                            let score = reading.areaScores.first { $0.area == area }!.score
                            VStack(spacing: 8) {
                                ZStack(alignment: .bottom) {
                                    Capsule().fill(areaColor(area).opacity(0.12)).frame(height: 56)
                                    Capsule().fill(areaColor(area).opacity(0.7)).frame(height: CGFloat(score) * 0.56)
                                }.frame(width: 10, height: 56)
                                AppText("\(score)").font(.system(size: 12, weight: .medium, design: .rounded))
                                AppText(area.rawValue).font(.system(size: 10)).foregroundStyle(OracleTheme.muted).lineLimit(1)
                            }.frame(width: 26).accessibilityElement(children: .ignore).accessibilityLabel(L10n.t("\(area.rawValue)，娱乐指数 \(score)"))
                        }
                    }
                }
                HStack {
                    ForEach([LifeArea.family, .mood]) { area in
                        Label(L10n.t("\(area.rawValue) \(reading.areaScores.first { $0.area == area }!.score)"), systemImage: area.symbol)
                    }
                    Spacer()
                    AppText("娱乐指数 / 100")
                }.font(.system(size: 10)).foregroundStyle(OracleTheme.muted)
            }
        }
    }

    private var invitationCard: some View {
        OracleCard {
            VStack(alignment: .leading, spacing: 19) {
                HStack(spacing: 8) {
                    Image(systemName: "sun.horizon").foregroundStyle(OracleTheme.accent)
                    AppText(reading.headline).font(.system(size: 17, weight: .medium))
                }
                AppText(L10n.content(reading.summary, english: "Use these notes as a reflection prompt. Choose one small, realistic action for this period.")).font(.system(size: 14)).lineSpacing(7)
                HStack(alignment: .top, spacing: 25) {
                    VStack(alignment: .leading, spacing: 9) {
                        Label(L10n.t("适合"), systemImage: "leaf").foregroundStyle(OracleTheme.sage)
                        AppText(reading.suggestion)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 9) {
                        Label(L10n.t("放一放"), systemImage: "cloud").foregroundStyle(OracleTheme.accent)
                        AppText(reading.avoid)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.font(.system(size: 12)).lineSpacing(5)
            }
        }
    }

    private var luckyCard: some View {
        OracleCard {
            VStack(alignment: .leading, spacing: 22) {
                sectionTitle(period == .day ? "小小幸运" : "本期幸运", subtitle: "LITTLE CHARMS")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: period == .day ? 4 : 3), spacing: 24) {
                    ForEach(reading.visibleLuckyItems) { item in
                        VStack(spacing: 9) {
                            Group {
                                if let hex = item.colorHex {
                                    RoundedRectangle(cornerRadius: 10).fill(Color(hex: hex)).frame(width: 30, height: 30)
                                } else if item.label == "幸运数字" {
                                    AppText(item.value).font(.system(size: 28, weight: .light, design: .rounded)).foregroundStyle(OracleTheme.accent)
                                } else {
                                    Image(systemName: item.symbol).font(.system(size: 25, weight: .light)).foregroundStyle(OracleTheme.sage)
                                }
                            }.frame(height: 34)
                            AppText(item.label == "幸运数字" ? "本期数字" : item.value)
                                .font(.system(size: 11, weight: .medium)).multilineTextAlignment(.center)
                                .frame(minHeight: 30).fixedSize(horizontal: false, vertical: true)
                            AppText(item.label).font(.system(size: 9)).foregroundStyle(OracleTheme.muted)
                        }.frame(maxWidth: .infinity).accessibilityElement(children: .ignore)
                            .accessibilityLabel(L10n.t("\(item.label)，\(item.value)"))
                    }
                }
                AppText("小小仪式即可，不用为幸运额外花钱。")
                    .font(.system(size: 10)).foregroundStyle(OracleTheme.muted)
            }
        }
    }

    private var tasksCard: some View {
        OracleCard {
            VStack(alignment: .leading, spacing: 20) {
                sectionTitle("让心慢下来的三件小事", subtitle: "")
                AppText("\(selectedDate.formatted(.dateTime.month().day())) · 每天换一点新意，随时可以跳过")
                    .font(.system(size: 10)).foregroundStyle(OracleTheme.muted)
                ForEach(reading.tasks) { task in
                    let done = account.isDone(task.id)
                    Button { account.toggleTask(task.id) } label: {
                        HStack(alignment: .top, spacing: 13) {
                            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 24, weight: .light)).foregroundStyle(done ? OracleTheme.sage : OracleTheme.muted)
                            VStack(alignment: .leading, spacing: 8) {
                                AppText(task.title).font(.system(size: 14, weight: .medium)).strikethrough(done)
                                    .accessibilityIdentifier("gentleTaskTitle.\(task.id)")
                                AppText(task.detail).font(.system(size: 11)).foregroundStyle(OracleTheme.muted).lineSpacing(5)
                            }
                            Spacer(minLength: 0)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.plain).accessibilityAddTraits(done ? .isSelected : [])
                    if task.id != reading.tasks.last?.id { Divider().overlay(OracleTheme.line.opacity(0.5)) }
                }
                AppText("它们是日常休息的小邀请，不是治疗方案。")
                    .font(.system(size: 10)).foregroundStyle(OracleTheme.muted)
            }
        }
    }

    private var detailedAreas: some View {
        VStack(alignment: .leading, spacing: 18) {
            AppText(L10n.f("%@的五个生活角度", L10n.t(period.title))).font(.system(size: 18, weight: .semibold))
            ForEach(reading.areaGuidance) { item in
                OracleCard {
                    VStack(alignment: .leading, spacing: 19) {
                        HStack(spacing: 12) {
                            AppText(item.area.rawValue).font(.system(size: 21, weight: .semibold))
                            AppText("\(item.score)").font(.system(size: 17, design: .rounded)).foregroundStyle(areaColor(item.area))
                            GeometryReader { geometry in
                                Capsule().fill(areaColor(item.area).opacity(0.12))
                                    .overlay(alignment: .leading) { Capsule().fill(areaColor(item.area).opacity(0.75)).frame(width: geometry.size.width * Double(item.score) / 100) }
                            }.frame(width: 88, height: 9)
                            Spacer(minLength: 0)
                        }
                        AppText(item.text).font(.system(size: 15)).lineSpacing(9).fixedSize(horizontal: false, vertical: true)
                    }
                }.accessibilityIdentifier("areaGuidance.\(item.area.rawValue)")
            }
        }
    }

    private var interpretations: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("心理解读 · 五个角度", subtitle: "INNER NOTES")
            HStack {
                AppText(latestReport == nil ? "星座灵感版 · 完成 20 问可加入答题线索" : "星座灵感 + 最近一次答题线索")
                    .font(.system(size: 10)).foregroundStyle(OracleTheme.muted)
                Spacer(minLength: 4)
                Button(L10n.t("去自问")) { ask() }.font(.system(size: 11, weight: .semibold))
            }
            ForEach(reading.interpretations) { item in
                Button { selectedInterpretation = item } label: {
                    OracleCard {
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Label(L10n.t(item.area.rawValue), systemImage: item.area.symbol)
                                    .font(.system(size: 11, weight: .medium)).foregroundStyle(areaColor(item.area))
                                    .padding(.horizontal, 11).padding(.vertical, 7)
                                    .background(areaColor(item.area).opacity(0.09), in: Capsule())
                                Spacer()
                                AppText("展开全文").font(.system(size: 10)).foregroundStyle(OracleTheme.accent)
                                Image(systemName: "arrow.up.right").font(.system(size: 10)).foregroundStyle(OracleTheme.accent)
                            }
                            AppText(item.title).font(.system(size: 18, weight: .medium)).multilineTextAlignment(.leading)
                            AppText(item.text).font(.system(size: 13)).lineSpacing(6).lineLimit(3)
                                .multilineTextAlignment(.leading).foregroundStyle(OracleTheme.muted)
                            AppText(item.basis).font(.system(size: 9)).foregroundStyle(OracleTheme.muted).multilineTextAlignment(.leading)
                        }
                    }
                }.buttonStyle(.plain).accessibilityIdentifier("interpretation.\(item.area.rawValue)")
            }
        }
    }

    private func move(_ direction: Int) {
        selectedDate = reading.calendar.date(byAdding: period.unit, value: direction, to: selectedDate) ?? selectedDate
        followsToday = false
    }
    private func sectionTitle(_ text: String, subtitle: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                AppText(text).font(.system(size: 16, weight: .semibold))
                Spacer()
                Eyebrow(text: subtitle)
            }
            AppText(text).font(.system(size: 16, weight: .semibold))
        }
    }
    private func areaColor(_ area: LifeArea) -> Color {
        switch area {
        case .love: Color(hex: 0xB77879)
        case .wealth: Color(hex: 0xAB854A)
        case .career: Color(hex: 0x879578)
        case .study: Color(hex: 0x7E94A1)
        case .social: Color(hex: 0xA38CA2)
        case .family: OracleTheme.accent
        case .mood: OracleTheme.sage
        }
    }
}

struct InterpretationDetail: View {
    let item: AreaReading
    let period: ReadingPeriod
    let rangeLabel: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    Eyebrow(text: "INNER NOTES / \(item.area.rawValue)", color: OracleTheme.accent)
                    AppText(item.title).font(.system(size: 29, weight: .medium)).lineSpacing(7)
                    AppText("\(period.title) · \(rangeLabel)").font(.system(size: 12)).foregroundStyle(OracleTheme.muted)
                    AppText(item.text).font(.system(size: 16)).lineSpacing(10)
                    Divider()
                    AppText(item.basis).font(.system(size: 11)).foregroundStyle(OracleTheme.muted)
                    AppText("内容是一份自我观察邀请，不代表确定性格、心理诊断或未来结果。")
                        .font(.system(size: 11)).foregroundStyle(OracleTheme.muted).lineSpacing(6)
                }.padding(28)
            }.background(OracleTheme.background).foregroundStyle(OracleTheme.ink)
                .navigationTitle(L10n.t("\(item.area.rawValue)解读")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.t("完成")) { dismiss() } } }
        }.tint(OracleTheme.accent).presentationDragIndicator(.visible)
    }
}

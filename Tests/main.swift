import Foundation

var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
    checks += 1
}

func report(_ answers: [Int: Int]) -> DecisionReport {
    DecisionReport(date: .now, title: "测试一个新方向", category: .life, answers: answers)
}

let questions = DecisionQuestion.all
check(questions.count == 20, "Must contain exactly 20 questions")
check(Set(questions.map(\.id)).count == 20, "Question IDs must be unique")
for dimension in DecisionDimension.allCases {
    check(questions.filter { $0.dimension == dimension }.count == 4, "Each dimension needs four questions")
}
check(questions.allSatisfy { $0.options.count == 4 }, "Every question needs four options")

let lowest = Dictionary(uniqueKeysWithValues: questions.map { ($0.id, 0) })
let highest = Dictionary(uniqueKeysWithValues: questions.map { ($0.id, 3) })
check(report(lowest).score == 0, "Lower endpoint should be zero")
check(report(highest).score == 100, "Upper endpoint should be 100")
check(report(highest).archetype == "胸有成竹型", "Fully prepared profile")
check(report(highest).dimensions.allSatisfy { $0.value == 100 }, "All dimensions at upper bound")

var highRisk = highest
highRisk[9] = 0
check(report(highRisk).score > 90, "Risk override should be exercised with a high total")
check(report(highRisk).archetype == "需要缓冲型", "High scores must never obscure unaffordable downside")
check(report(highRisk).recommendation.contains("暂缓"), "Risk override should advise pausing")
var emotional = highest
emotional[13] = 0
check(report(emotional).archetype == "情绪上头型", "Strong emotion overrides a high total")
var impulsive = lowest
impulsive[9] = 2
impulsive[13] = 2
impulsive[19] = 2
check(report(impulsive).archetype == "心血来潮型", "Low readiness without overrides")
let middle = Dictionary(uniqueKeysWithValues: questions.map { ($0.id, 2) })
check(report(middle).archetype == "蓄势待发型", "Moderate preparation")
var missingEvidence = highest
for question in questions where question.dimension == .evidence { missingEvidence[question.id] = 0 }
check(report(missingEvidence).weakest.dimension == .evidence, "Find genuine weak dimension")
check(report(missingEvidence).archetype != "胸有成竹型", "A missing dimension prevents top classification")
check(report(missingEvidence).recommendation.contains("事实依据"), "Advice must reflect weakest dimension")

for question in questions {
    var previous = -1
    for value in 0...3 {
        var answers = middle
        answers[question.id] = value
        let score = report(answers).score
        check(score >= previous, "Readiness should be monotonic")
        check((0...100).contains(score), "Score must be bounded")
        previous = score
    }
}

let encoded = try JSONEncoder().encode(report(highest))
let decoded = try JSONDecoder().decode(DecisionReport.self, from: encoded)
check(decoded.answers == highest && decoded.score == 100, "Integer answer keys must survive persistence")

let suiteName = "worthit.tests.\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suiteName)!
defer { defaults.removePersistentDomain(forName: suiteName) }
let store = DecisionStore(defaults: defaults)
let unfinished = DecisionDraft(title: "未完成", category: .career, answers: [0: 3])
check(store.finish(unfinished) == nil && store.reports.isEmpty, "Incomplete surveys must not generate results")
store.draft = unfinished
store.persist()
check(DecisionStore(defaults: defaults).draft?.answers[0] == 3, "Draft must survive relaunch")
let finished = DecisionDraft(title: "完整决定", category: .life, answers: highest, currentIndex: 19)
let saved = store.finish(finished)!
check(store.draft == nil && store.reports.count == 1, "Completion clears draft and adds one report")
store.updateReflection(id: saved.id, text: "先做一个小实验")
let reloaded = DecisionStore(defaults: defaults)
check(reloaded.reports.first?.reflection == "先做一个小实验", "Reflection must survive relaunch")
reloaded.delete(id: saved.id)
check(DecisionStore(defaults: defaults).reports.isEmpty, "Deletion must persist")

// Registration, zodiac, account isolation and deterministic calendar content.
check(AccountMethod.phone.isValid("13800138000"), "Valid mainland number")
check(!AccountMethod.phone.isValid("123"), "Invalid phone is blocked")
check(AccountMethod.email.isValid("test@example.com"), "Email format")
check(!AccountMethod.email.isValid("not-an-email"), "Invalid email")
check(!AccountMethod.wechat.isValid("plain-wechat-id"), "Plain text can never authenticate WeChat")
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
let birthDate = calendar.date(from: DateComponents(year: 1998, month: 6, day: 15, hour: 8, minute: 30))!
let birth = BirthDetails(date: birthDate, includeTime: true, calendar: calendar)
check(birth.hour == 8 && birth.minute == 30, "Precise local birth time")
check(BirthDetails(date: birthDate, includeTime: false, calendar: calendar).hour == nil, "Unknown time stays unknown")
check(ZodiacSign.forBirthday(month: 6, day: 15) == .gemini, "Birthday sign")
check(ZodiacSign.forBirthday(month: 12, day: 31) == .capricorn, "Year-end sign")
check(ZodiacSign.forBirthday(month: 1, day: 20) == .aquarius, "Boundary date")
for (month, day, expected) in [(3,21,ZodiacSign.aries),(4,20,.taurus),(5,21,.gemini),(6,22,.cancer),(7,23,.leo),(8,23,.virgo),(9,23,.libra),(10,24,.scorpio),(11,23,.sagittarius),(12,22,.capricorn),(1,20,.aquarius),(2,19,.pisces)] {
    check(ZodiacSign.forBirthday(month: month, day: day) == expected, "All twelve signs")
}
let profile = UserProfile(method: .email, identifier: "test@example.com", nickname: "小满", birth: birth)
let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 12))!
let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
func star(_ date: Date, _ period: ReadingPeriod = .day, _ report: DecisionReport? = nil) -> StarReading {
    StarReading(profile: profile, period: period, date: date, latestReport: report, calendar: calendar)
}
let daily = star(today)
check(daily.overall == star(today).overall, "Same day stays stable")
check(daily.luckyItems.map(\.value) == star(today).luckyItems.map(\.value), "Lucky values stay stable after relaunch")
check(daily.tasks.map(\.title) != star(tomorrow).tasks.map(\.title), "Daily tasks change")
check(daily.luckyItems.count == 8, "Eight lucky properties")
check(daily.interpretations.count == 5 && Set(daily.interpretations.map(\.id)).count == 5, "Exactly five distinct interpretation areas")
check(daily.interpretations.allSatisfy { $0.basis.contains("灵感") }, "No answer history is never fabricated")
check(star(today, .day, report(highest)).interpretations.allSatisfy { $0.basis.contains("答题") }, "Actual answers are referenced")
for day in 0..<365 {
    let date = calendar.date(byAdding: .day, value: day, to: today)!
    let next = calendar.date(byAdding: .day, value: day + 1, to: today)!
    check(star(date).tasks.count == 3 && Set(star(date).tasks.map(\.title)).count == 3, "Three unique gentle tasks")
    check(zip(star(date).tasks, star(next).tasks).allSatisfy { $0.title != $1.title }, "Every task differs on adjacent days")
    check(star(date).areaScores.allSatisfy { (0...100).contains($0.score) }, "Entertainment scores bounded")
}
for period in ReadingPeriod.allCases {
    let reading = star(today, period)
    let within = reading.interval.start.addingTimeInterval(100)
    check(reading.periodKey == star(within, period).periodKey, "Scores use a stable period interval")
    check(reading.tasks.map(\.id) == daily.tasks.map(\.id), "Daily task IDs do not depend on browsing period")
}
check(star(today, .week).periodKey == star(tomorrow, .week).periodKey, "Same ISO-style week")
check(Set(ReadingPeriod.allCases.map { star(today, $0).periodKey }).count == 4, "Each period has a distinct key")

let account = AccountStore(defaults: defaults)
check(account.activeProfile == nil, "Registration is required initially")
check(!account.register(method: .wechat, identifier: "not-verified", nickname: "测试", birth: birth), "WeChat cannot use unverified registration")
_ = store.finish(finished)
check(account.register(method: .email, identifier: "first@example.com", nickname: "小满", birth: birth), "Local registration")
let first = account.activeProfile!
check(account.decisionStore(for: first).reports.count == store.reports.count, "Original records migrate to first profile")
account.appearance = .dark
account.toggleTask(daily.tasks[0].id)
let persistedAccount = AccountStore(defaults: defaults)
check(persistedAccount.activeProfile?.id == first.id && persistedAccount.appearance == .dark, "Profile and appearance persist")
check(persistedAccount.isDone(daily.tasks[0].id), "Task checkmarks persist")
account.signOut()
check(account.activeProfile == nil, "Logout gates access")
check(account.register(method: .email, identifier: "second@example.com", nickname: "小叶", birth: birth), "Second local account")
check(account.decisionStore(for: account.activeProfile!).reports.isEmpty, "Another account never inherits old decisions")
check(!account.isDone(daily.tasks[0].id), "Task completion is account scoped")
account.resume(first)
check(account.decisionStore(for: first).reports.count == store.reports.count, "Returning account retains records")
account.update(nickname: "改名", birth: birth)
check(account.activeProfile?.nickname == "改名" && account.activeProfile?.id == first.id, "Profile editing keeps ownership")
let verified = WeChatUser(id: "server-verified-id", nickname: "微信朋友")
account.registerWeChat(verified, nickname: "微信朋友", birth: birth)
let verifiedProfile = account.activeProfile!
account.signOut()
account.resume(verifiedProfile)
check(account.activeProfile == nil, "Plain local resume never bypasses WeChat authorization")
check(account.resumeVerifiedWeChat(verified), "Verified backend identity can resume WeChat profile")
check(!account.register(method: .phone, identifier: "13800138000", nickname: "未验证", birth: birth), "Plain phone registration cannot bypass OTP")
let phoneUser = WeChatUser(id: "verified-phone-id", nickname: "旅人", phone: "13800138000", providers: ["phone"])
account.registerPhone(phoneUser, nickname: "手机旅人", birth: birth)
let phoneProfile = account.activeProfile!
account.signOut(); account.resume(phoneProfile)
check(account.activeProfile == nil, "Local phone resume is blocked")
check(account.resumeVerifiedPhone(phoneUser), "Verified phone identity resumes its own profile")
check(account.activeProfile?.serverUserID == phoneUser.id, "Server identity persists with phone profile")
check(star(today, .day).visibleLuckyItems.count == 8, "Day keeps eight lucky items")
for period in [ReadingPeriod.week, .month, .year] {
    let reading = star(today, period)
    check(reading.visibleLuckyItems.map(\.label) == ["幸运颜色", "幸运数字", "幸运石"], "Non-daily luck contains only color, number, stone")
    check(reading.areaGuidance.count == 5 && reading.areaGuidance.allSatisfy { $0.text.count > 150 }, "Five detailed life areas")
}
let lots = account.lotteryStore(for: phoneProfile)
check(CulturalLot.all.count == 100 && Set(CulturalLot.all.map(\.id)).count == CulturalLot.all.count, "Original lots have unique IDs")
for emotion in DrawEmotion.allCases {
    let record = lots.draw(emotion: emotion)
    check(record.emotion == emotion && CulturalLot.all.contains(where: { $0.id == record.lotID }), "Drawing respects selected emotion")
    check(!record.lot.poem.isEmpty && !record.interpretation.isEmpty && !record.nextStep.isEmpty, "Poem, reading and action are present")
    if emotion == .sad || emotion == .grieving { check(record.interpretation.contains("不"), "Supportive reading has nonjudgmental reassurance") }
}
check(account.lotteryStore(for: phoneProfile).records.count == 5, "Draws survive relaunch")
let phoneDecisions = account.decisionStore(for: phoneProfile)
_ = phoneDecisions.finish(finished)
phoneDecisions.draft = unfinished; phoneDecisions.persist(); phoneDecisions.clearHistory()
check(account.decisionStore(for: phoneProfile).reports.isEmpty && account.decisionStore(for: phoneProfile).draft == nil, "Clear cache removes reports and draft")
check(account.lotteryStore(for: phoneProfile).records.count == 5, "Question clearing preserves lottery history")
check(!account.decisionStore(for: first).reports.isEmpty, "Clearing stays account scoped")
account.deleteActiveProfile()
check(account.activeProfile == nil && account.lotteryStore(for: phoneProfile).records.isEmpty, "Delete account clears owned lottery archive")
check(account.profiles.contains(where: { $0.id == first.id }), "Delete preserves other profiles")
let migrationSuite = "worthit.migration-test.\(UUID().uuidString)"
let migrationDefaults = UserDefaults(suiteName: migrationSuite)!
defer { migrationDefaults.removePersistentDomain(forName: migrationSuite) }
let original = DecisionStore(defaults: migrationDefaults)
_ = original.finish(finished)
let migrationAccount = AccountStore(defaults: migrationDefaults)
_ = migrationAccount.register(method: .email, identifier: "old@example.com", nickname: "旧档案", birth: birth)
check(migrationAccount.decisionStore(for: migrationAccount.activeProfile!).reports.count == 1, "Legacy archive migrated once")
migrationAccount.deleteActiveProfile()
_ = migrationAccount.register(method: .email, identifier: "new@example.com", nickname: "新档案", birth: birth)
check(migrationAccount.decisionStore(for: migrationAccount.activeProfile!).reports.isEmpty, "Deleted legacy records never resurrect in a new account")
let legacyAnswers = Dictionary(uniqueKeysWithValues: questions.prefix(15).map { ($0.id, 3) })
let legacyReport = report(legacyAnswers)
check(legacyReport.questionCount == 15 && legacyReport.score == 100, "Legacy 15-answer reports keep original denominator")
check(legacyReport.dimensions.allSatisfy { $0.value == 100 }, "Legacy dimension scores never change")
check(report(highest).questionCount == 20 && report(highest).score == 100, "20 questions use 60 point denominator")
check(GuanyinLot.all.count == 100 && Set(GuanyinLot.all.map(\.id)) == Set(1...100), "Traditional lots are complete, unique and sequential")
check(Set(CulturalLot.all.map(\.poem)).count == 100, "Original 100 poems are distinct")
let fourth = GuanyinLot.all[3]
check(fourth.title == "玉莲会十朋" && fourth.rank == "上签" && fourth.palace == "子宫", "Fourth lot matches supplied recension")
check(fourth.poem.contains("千年古镜复重圆") && fourth.omens.count == 15, "Fourth lot contains full poem and traditional entries")
let traditionalDraw = lots.draw(emotion: .grieving, mode: .guanyin)
check(traditionalDraw.mode == .guanyin && traditionalDraw.guanyinLot != nil, "Mode stored with each draw")
check(traditionalDraw.interpretation.contains("失落"), "Traditional reading adapts to grief")
check(account.lotteryStore(for: phoneProfile).records.first?.mode == .guanyin, "Mode survives persistence")
for lot in GuanyinLot.all {
    check(lot.poem.components(separatedBy: "\n").count == 4 && !lot.story.isEmpty && !lot.explanation.isEmpty, "Each traditional entry includes poem, story and explanation")
    check(!lot.omens.isEmpty && Set(lot.omens.map(\.id)).count == lot.omens.count && !lot.omens.contains(where: { $0.text.contains("→") }), "Traditional entries preserve summaries and distinct subjects")
    check(lot.modernSections.filter { $0.1.contains(lot.theme) }.count == 1 && lot.modernSections.first?.1.hasPrefix(lot.theme) == true, "Full theme appears only once in the overall reading")
    check(!DrawEmotion.allCases.contains(where: { lot.reflection(emotion: $0).contains(lot.theme) }), "Emotion introduction does not repeat the overall theme")
    check(lot.modernSections.count == 15 && lot.modernSections.first(where: { $0.0 == "健康与照顾" })!.1.contains("不能"), "Separate modern sections avoid medical claims")
}
let localAccount = AccountStore(defaults: migrationDefaults)
check(localAccount.register(method: .local, identifier: UUID().uuidString, nickname: "本机用户", birth: birth), "Contact-free local setup works")
let localProfile = localAccount.activeProfile!
check(localProfile.isLocalOnly && localProfile.serverUserID == nil, "Local profile never claims server verification")
localAccount.language = .ar
let localizedAccount = AccountStore(defaults: migrationDefaults)
check(localizedAccount.language == .ar && localizedAccount.language.isRTL, "Arabic preference and direction persist")
localAccount.signOut(); localAccount.resume(localProfile)
check(localAccount.activeProfile?.id == localProfile.id, "Unverified local archive can resume only as local")
check(AppLanguage.allCases.count == 29, "28 explicit languages plus system default")
AppLanguageState.shared.language = .zhHans
print("Passed \(checks) checks: scoring, account gating/isolation, persistence, zodiac and 365-day content rotation.")

// Action selection stays unique across modes, persistence and the 100-record history cap.
check(SmallAction.all.count >= 200 && Set(SmallAction.all.map(\.id)).count == SmallAction.all.count, "Action catalog has over 200 distinct IDs")
check(Set(SmallAction.all.map(\.text)).count == SmallAction.all.count, "Action texts are distinct")
for emotion in DrawEmotion.allCases {
    let id = UUID()
    let count = SmallAction.all.filter { $0.emotions.contains(emotion) }.count
    var actionTexts = Set<String>()
    for draw in 0..<count {
        let freshStore = LotteryStore(profileID: id, defaults: migrationDefaults)
        let record = freshStore.draw(emotion: emotion, mode: draw % 2 == 0 ? .guanyin : .original)
        check(record.smallAction != nil && actionTexts.insert(record.nextStep).inserted, "Actions never repeat across relaunch or draw mode")
        check(LotteryStore(profileID: id, defaults: migrationDefaults).records.first?.smallAction?.id == record.smallAction?.id, "Opening history preserves the same action")
    }
    let exhausted = LotteryStore(profileID: id, defaults: migrationDefaults).draw(emotion: emotion)
    check(exhausted.smallAction == nil && exhausted.actionCatalogVersion == 1, "Exhaustion does not recycle an old action")
}
for lot in GuanyinLot.all {
    check(lot.modernSections.dropFirst(2).allSatisfy { $0.1.count > 180 }, "Every practical modern section is expanded")
}
// The UTC eclipse of 2024-04-08 provides an external astronomical sanity check.
let eclipseSun = WI_NatalLongitude(0, 2024, 4, 8, 18, 18, 0, 0)
let eclipseMoon = WI_NatalLongitude(1, 2024, 4, 8, 18, 18, 0, 0)
check(abs(eclipseSun - eclipseMoon) < 0.1 && (19...20).contains(eclipseSun), "Solar eclipse sun and moon are conjunct in Aries")
var knownBirth = birth
knownBirth.hour = 12; knownBirth.minute = 0; knownBirth.place = BirthPlace.presets[0]
let natal = NatalChart.calculate(knownBirth)
check(natal.placements.count == 12 && natal.placements.allSatisfy { $0.longitude.isFinite && (0..<360).contains($0.longitude) && (1...12).contains($0.house!) }, "Complete birth yields finite planets, angles and whole-sign houses")
var noTime = knownBirth; noTime.hour = nil
check(NatalChart.calculate(noTime).placements.isEmpty, "Unknown time never invents placements")
var polar = knownBirth; polar.place = BirthPlace(name: "极区", latitude: 70, longitude: 20, timeZoneID: "Europe/Oslo")
let polarChart = NatalChart.calculate(polar)
check(polarChart.placements.count == 11 && polarChart.placements.allSatisfy { $0.house == nil }, "Unsupported polar ascendant produces no fabricated houses")
check(BirthPlace(name: "无效", latitude: 91, longitude: 0, timeZoneID: "Asia/Shanghai").valid == false, "Invalid coordinates rejected")
check(BirthPlace(name: "无效", latitude: 0, longitude: 0, timeZoneID: "not/a-zone").valid == false, "Invalid timezone rejected")
var dst = knownBirth; dst.year = 2024; dst.month = 3; dst.day = 10; dst.hour = 2; dst.minute = 30; dst.place = BirthPlace.presets.first { $0.name == "纽约" }
check(NatalChart.calculate(dst).placements.isEmpty, "Nonexistent DST wall time rejected")
print("V6 checks passed; total assertions: \(checks)")

let legacyLotID = UUID()
let legacyRecord = DrawRecord(date: .now, emotion: .sad, lotID: 4)
let legacyData = try JSONEncoder().encode([legacyRecord, legacyRecord])
var legacyJSON = try JSONSerialization.jsonObject(with: legacyData) as! [[String: Any]]
for index in legacyJSON.indices { legacyJSON[index].removeValue(forKey: "smallAction"); legacyJSON[index].removeValue(forKey: "actionCatalogVersion") }
migrationDefaults.set(try JSONSerialization.data(withJSONObject: legacyJSON), forKey: LotteryStore.key(legacyLotID))
let migratedLots = LotteryStore(profileID: legacyLotID, defaults: migrationDefaults)
check(Set(migratedLots.records.compactMap { $0.smallAction?.id }).count == 2, "Legacy repeated emotional actions migrate to distinct saved actions")
check(LotteryStore(profileID: legacyLotID, defaults: migrationDefaults).records.map { $0.smallAction?.id } == migratedLots.records.map { $0.smallAction?.id }, "Legacy migration is stable across reopens")
print("Final V6 assertions: \(checks)")

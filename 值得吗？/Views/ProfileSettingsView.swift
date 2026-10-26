import SwiftUI

struct ProfileSettingsView: View {
    @Bindable var account: AccountStore
    let profile: UserProfile
    @State private var showEdit = false
    let history: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "A LITTLE MORE ABOUT YOU", color: OracleTheme.accent)
                AppText(L10n.f("%@，\n按你的节奏来。", profile.nickname))
                    .font(.system(size: 31, weight: .medium)).lineSpacing(6)
            }
            NavigationLink { ZodiacDetailView(account: account, profile: profile) } label: {
                ZodiacIdentityCard(birth: profile.birth)
                    .overlay(alignment: .bottomTrailing) { Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(OracleTheme.muted).padding(20) }
            }.buttonStyle(.plain).accessibilityIdentifier("profile.zodiacDetails")
            OracleCard {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        AppText("我的星座属性").font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Eyebrow(text: "NO. \(profile.signature)", color: OracleTheme.accent)
                    }
                    AppText(profile.zodiac.invitation).font(.system(size: 14)).lineSpacing(7)
                    HStack {
                        AppText(profile.birth.label).font(.system(size: 11)).foregroundStyle(OracleTheme.muted)
                        Spacer()
                        Button(L10n.t("编辑")) { showEdit = true }.font(.system(size: 12, weight: .semibold))
                            .accessibilityIdentifier("editProfile")
                    }
                    AppText("生日区间匹配 · 时间用于节律标签 · 非完整星盘")
                        .font(.system(size: 10)).foregroundStyle(OracleTheme.muted)
                }
            }

            Button(action: history) {
                HStack {
                    Label(L10n.t("问答历史"), systemImage: "clock.arrow.circlepath")
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12))
                }.font(.system(size: 14)).padding(21)
                    .background(OracleTheme.card, in: RoundedRectangle(cornerRadius: 21))
            }.buttonStyle(.plain).accessibilityIdentifier("profile.history")
        }.foregroundStyle(OracleTheme.ink)
            .sheet(isPresented: $showEdit) { EditProfileView(account: account, profile: profile) }
    }
}

struct EditProfileView: View {
    let account: AccountStore
    @Environment(\.dismiss) private var dismiss
    @State private var nickname: String
    @State private var birthday: Date
    @State private var knowsTime: Bool
    private let savedPlace: BirthPlace?
    init(account: AccountStore, profile: UserProfile) {
        self.account = account
        savedPlace = profile.birth.place
        _nickname = State(initialValue: profile.nickname)
        _birthday = State(initialValue: profile.birth.date)
        _knowsTime = State(initialValue: profile.birth.hour != nil)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    BirthFields(nickname: $nickname, birthday: $birthday, knowsTime: $knowsTime)
                    ZodiacIdentityCard(birth: BirthDetails(date: birthday, includeTime: knowsTime))
                    AppText("修改出生信息会更新星座属性和星笺内容，已完成的答题记录保留。可在星座档案中补充出生地与时区，计算星体位置和宫位。")
                        .font(.system(size: 12)).foregroundStyle(OracleTheme.muted).lineSpacing(6)
                    PrimaryButton(title: "保存我的星座属性", enabled: !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                        var birth = BirthDetails(date: birthday, includeTime: knowsTime)
                        birth.place = savedPlace
                        account.update(nickname: nickname, birth: birth)
                        dismiss()
                    }.accessibilityIdentifier("saveProfile")
                }.padding(24)
            }
            .background(OracleTheme.background).foregroundStyle(OracleTheme.ink)
            .navigationTitle(L10n.t("出生信息")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.t("取消")) { dismiss() } } }
        }.tint(OracleTheme.accent).presentationDragIndicator(.visible)
    }
}

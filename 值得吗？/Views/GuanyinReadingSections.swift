import SwiftUI

struct GuanyinReadingSections: View {
    let lot: GuanyinLot
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            AppText("现代解读").font(.system(size: 21, weight: .semibold))
            AppText("以下由本应用整理，是自我观察的建议，与古文断语分别展示。")
                .font(.system(size: 11)).foregroundStyle(OracleTheme.muted).lineSpacing(5)
            ForEach(lot.modernSections, id: \.0) { section in
                DisclosureGroup {
                    AppText(section.1).font(.system(size: 14)).lineSpacing(8).padding(.top, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } label: { AppText(section.0).font(.system(size: 15, weight: .medium)) }
                    .padding(19).background(OracleTheme.card, in: RoundedRectangle(cornerRadius: 20))
            }
            OracleCard {
                VStack(alignment: .leading, spacing: 15) {
                    AppText("典故 · \(lot.title)").font(.system(size: 17, weight: .semibold))
                    AppText(lot.story).font(.system(size: 14)).lineSpacing(8)
                    AppText("故事提要按签题整理；民间传说、演义与史实有别。")
                        .font(.system(size: 10)).foregroundStyle(OracleTheme.muted)
                }
            }
            AppText("传统原文").font(.system(size: 21, weight: .semibold))
            AppText("各地签本的诗句、故事和等第存在差异。本版采用七言四句通行录文，不代表任何寺院认证。")
                .font(.system(size: 11)).foregroundStyle(OracleTheme.muted).lineSpacing(6)
            OracleCard {
                VStack(alignment: .leading, spacing: 19) {
                    AppText("诗意").font(.system(size: 15, weight: .semibold))
                    AppText(lot.poeticMeaning).lineSpacing(7)
                    AppText("解曰").font(.system(size: 15, weight: .semibold))
                    AppText(lot.explanation).lineSpacing(7)
                }.font(.system(size: 14))
            }
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 15) {
                    AppText("下面是旧时签本的文化条目，不是现实判断，也不用于疾病、孕产、投资或法律决定。")
                        .font(.system(size: 11)).foregroundStyle(OracleTheme.muted).lineSpacing(6)
                    ForEach(lot.omens) { omen in
                        HStack(alignment: .top) {
                            AppText(omen.subject).frame(width: 70, alignment: .leading)
                            AppText(omen.text).foregroundStyle(OracleTheme.muted)
                            Spacer(minLength: 0)
                        }.font(.system(size: 14))
                    }
                }.padding(.top, 16)
            } label: { AppText("仙机 · 传统条目").font(.system(size: 16, weight: .medium)) }
                .padding(20).background(OracleTheme.card, in: RoundedRectangle(cornerRadius: 20))
            NavigationLink { ContentSourcesView() } label: {
                Label(L10n.t("版本与来源"), systemImage: "text.book.closed").font(.system(size: 14))
            }
            NavigationLink { GuanyinLibraryView() } label: {
                Label(L10n.t("浏览完整 100 签"), systemImage: "books.vertical").font(.system(size: 14))
            }
        }
    }
}

struct GuanyinLibraryView: View {
    @State private var search = ""
    private var lots: [GuanyinLot] {
        guard !search.isEmpty else { return GuanyinLot.all }
        return GuanyinLot.all.filter { String($0.id) == search || $0.title.contains(search) || $0.poem.contains(search) }
    }
    var body: some View {
        List(lots) { lot in
            NavigationLink {
                ScrollView {
                    VStack(alignment: .leading, spacing: 25) {
                        AppText("第 \(lot.id) 签 · \(lot.title)").font(.system(size: 27, weight: .medium))
                        AppText("\(lot.rank) · \(lot.palace)（传统等第）").font(.system(size: 12)).foregroundStyle(OracleTheme.muted)
                        AppText(lot.poem).font(.system(size: 23, design: .serif)).lineSpacing(12)
                        GuanyinReadingSections(lot: lot)
                    }.padding(25)
                }.background(OracleTheme.background).navigationTitle(L10n.t("签谱阅读"))
            } label: {
                HStack(spacing: 15) {
                    AppText(String(format: "%03d", lot.id)).font(.system(size: 17, design: .rounded)).foregroundStyle(OracleTheme.accent)
                    VStack(alignment: .leading, spacing: 6) {
                        AppText(lot.title).font(.system(size: 15, weight: .medium))
                        AppText(lot.poem.components(separatedBy: "\n").first ?? "").font(.system(size: 11)).foregroundStyle(OracleTheme.muted)
                    }
                }.padding(.vertical, 7)
            }
        }.searchable(text: $search, prompt: "签号、签题或诗句")
            .scrollContentBackground(.hidden).background(OracleTheme.background)
            .navigationTitle(L10n.t("观音百签")).navigationBarTitleDisplayMode(.inline)
    }
}

import SwiftUI

struct ContentSourcesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                AppText("版本与来源").font(.system(size: 27, weight: .medium))
                AppText("问心签收录本应用原创的 100 首诗文。观音灵签采用七言四句通行录文版，签题、宫位和等第可能与个别寺庙或刻本不同，不能称为唯一正本。")
                AppText("传统签诗、诗意、解曰与旧时条目按古代文本整理。现代解读、行动建议和故事提要由本应用另写，分别标注，不照搬网站的现代释义。")
                Link("观音百签录文参考", destination: URL(string: "https://www.fzlgo.com/guan-yin-ling-qian/")!)
                Link("第四签版本对照", destination: URL(string: "https://www.nongli.com/item5/guanyin/4.html")!)
                Link("签诗版本差异 · 华人庙宇委员会", destination: URL(string: "https://www.ctc.org.hk/zh-hans/chim-search/")!)
                AppText("本应用与上述网站、寺院及组织无合作或背书关系。")
                AppText("诗文用于文化阅读，不据此判断身体、孕产、投资或法律结果。")
                Divider()
                AppText("小事中的古文灵感").font(.system(size: 18, weight: .medium))
                AppText("引用古代原文时随条目标注篇名与链接，行动建议另行创作。简体字整理不改变原句意思；其余日常小事为应用原创。")
                Link("《论语·子路》", destination: URL(string: "https://ctext.org/analects/zi-lu/zh")!)
                Link("《论语·学而》", destination: URL(string: "https://ctext.org/analects/xue-er/zh")!)
                Link("《周易·系辞下》", destination: URL(string: "https://ctext.org/book-of-changes/xi-ci-xia/zh")!)
                Divider()
                AppText("星体计算").font(.system(size: 18, weight: .medium))
                AppText("Astronomy Engine · Don Cross · MIT License。版本固定于 865d3da7d8112bbc7911238052c6af4aaf877181。天体位置使用地心视黄经，宫位采用整宫制；占星文字为应用另写的文化阅读内容。")
                Link("Astronomy Engine · 源码与 MIT 授权", destination: URL(string: "https://github.com/cosinekitty/astronomy")!)
                Text(verbatim: "Copyright (c) 2019–2025 Don Cross. MIT License: permission is granted, free of charge, to use, copy, modify, merge, publish, distribute, sublicense, and/or sell this software, subject to retaining the copyright and permission notice. THE SOFTWARE IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND. Full license included below.").font(.system(size: 10))
                if let url = Bundle.main.url(forResource: "Astronomy-LICENSE", withExtension: "txt"), let license = try? String(contentsOf: url, encoding: .utf8) { Text(verbatim: license).font(.system(size: 10)) }
                Divider()
                AppText("摇签音效").font(.system(size: 18, weight: .medium))
                Text(verbatim: "“Toothpick Holder Shacking.wav” · KCJones321 · Freesound · CC0 1.0")
                Text(verbatim: "木质牙签筒摇动实录，经截取、淡入淡出与音量调整，用于模拟签筒碰撞。")
                Link("Freesound · KCJones321", destination: URL(string: "https://freesound.org/people/KCJones321/sounds/411204/")!)
                Link("CC0 1.0", destination: URL(string: "https://creativecommons.org/publicdomain/zero/1.0/")!)
            }.font(.system(size: 14)).lineSpacing(8).padding(26)
        }.background(OracleTheme.background).foregroundStyle(OracleTheme.ink)
            .navigationTitle(L10n.t("版本与来源")).navigationBarTitleDisplayMode(.inline)
    }
}

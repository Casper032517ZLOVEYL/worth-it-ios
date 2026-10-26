import SwiftUI

struct TreeHoleView: View {
    @Bindable var store: TreeHoleStore
    @State private var showConsent = false
    @State private var confirmClear = false
    @FocusState private var focused: Bool
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    AppText("树洞").font(.system(size: 27, weight: .semibold))
                    AppText("开心可以分享，委屈也有人听。").font(.system(size: 12)).foregroundStyle(OracleTheme.muted)
                }
                Spacer()
                Menu {
                    Button(L10n.t("聊天发送说明")) { showConsent = true }
                    Button(L10n.t("撤回聊天授权")) { store.revoke() }
                    Button(L10n.t("清空树洞对话"), role: .destructive) { confirmClear = true }
                } label: { Image(systemName: "ellipsis").padding(13).warmGlass(radius: 23) }.accessibilityIdentifier("tree.menu")
            }.padding(.horizontal, 24).padding(.vertical, 15)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 19) {
                        if store.messages.isEmpty { introduction }
                        ForEach(store.messages) { message in
                            HStack(alignment: .top) {
                                if message.role == "user" { Spacer(minLength: 35) }
                                VStack(alignment: .leading, spacing: 7) {
                                    AppText(message.role == "user" ? "我" : "树洞 · AI").font(.system(size: 10)).foregroundStyle(OracleTheme.muted)
                                    Text(verbatim: message.content).font(.system(size: 15)).lineSpacing(7).textSelection(.enabled)
                                }.padding(17).background(message.role == "user" ? OracleTheme.accent.opacity(0.13) : OracleTheme.card, in: RoundedRectangle(cornerRadius: 21))
                                if message.role != "user" { Spacer(minLength: 35) }
                            }.id(message.id)
                        }
                        if store.sending {
                            HStack(spacing: 10) { ProgressView(); AppText("正在认真听你说……").font(.system(size: 12)); Button(L10n.t("停止")) { store.cancel() } }.id("pending")
                        }
                        if let error = store.error {
                            AppText(error).font(.system(size: 12)).foregroundStyle(OracleTheme.accent).accessibilityIdentifier("tree.error")
                        }
                        if store.hasPending && !store.sending {
                            Button(L10n.t("重新发送")) { store.send(retry: true) }.accessibilityIdentifier("tree.retry")
                            AppText("这条消息尚未收到回复。").font(.system(size: 11)).foregroundStyle(OracleTheme.muted)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }.frame(maxWidth: 540).frame(maxWidth: .infinity).padding(24)
                }.scrollDismissesKeyboard(.interactively)
                    .onChange(of: store.messages.count) { _, _ in withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
                    .onChange(of: store.sending) { _, _ in withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { composer }
        .background(OracleTheme.background).foregroundStyle(OracleTheme.ink)
        .task { await store.refresh() }
        .onDisappear { store.cancel(); focused = false }
        .onChange(of: scenePhase) { _, phase in if phase != .active { store.cancel() } }
        .sheet(isPresented: $showConsent) { consentSheet }
        .confirmationDialog(L10n.t("清空树洞对话？"), isPresented: $confirmClear, titleVisibility: .visible) {
            Button(L10n.t("删除本机聊天记录"), role: .destructive) { store.clear() }
        } message: { AppText("删除本机保存的对话与草稿。已发送给服务商的内容遵循其隐私政策，不能通过清空本机记录撤回。") }
    }
    private var introduction: some View {
        VStack(alignment: .leading, spacing: 22) {
            Image(systemName: "leaf.circle").font(.system(size: 55, weight: .ultraLight)).foregroundStyle(OracleTheme.sage)
            AppText("把心里的话，\n放在这里一会儿。").font(.system(size: 29, weight: .medium)).lineSpacing(7)
            AppText("分享一件小开心，吐槽糟糕的一天，或一起把乱成一团的想法理顺。你可以直接告诉树洞：只听我说，先不要建议。")
                .font(.system(size: 14)).lineSpacing(7).foregroundStyle(OracleTheme.muted)
            FlowChips(select: { store.draft = $0; focused = true })
            OracleCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label(L10n.t(store.available ? "聊天服务已连接" : "聊天服务待接入"), systemImage: store.available ? "checkmark.circle" : "network.slash").font(.system(size: 14, weight: .medium)).accessibilityIdentifier("tree.status")
                    AppText(store.available ? "回复由 AI 生成，可能不准确。发送前请阅读聊天发送说明。" : "目前尚未连接可用的模型服务，暂时不能回复。你可以先把想说的话写下来，草稿仅保存在本机。")
                        .font(.system(size: 12)).lineSpacing(6).foregroundStyle(OracleTheme.muted)
                    if store.configured { Button(L10n.t("检查连接")) { Task { await store.refresh() } }.disabled(store.checking) }
                }
            }
            AppText("树洞不是心理诊疗服务。如果你正面临即时危险，请联系当地急救或身边可信赖的人。").font(.system(size: 10)).foregroundStyle(OracleTheme.muted).lineSpacing(5)
        }
    }
    private var composer: some View {
        VStack(spacing: 9) {
            if store.available && !store.consented {
                Button(L10n.t("阅读并开启树洞聊天")) { showConsent = true }.font(.system(size: 12)).accessibilityIdentifier("tree.consent")
            }
            HStack(alignment: .bottom, spacing: 12) {
                TextField(L10n.t("此刻，你想说些什么？"), text: $store.draft, axis: .vertical)
                    .lineLimit(1...5).font(.system(size: 14)).focused($focused).accessibilityIdentifier("tree.input")
                    .onChange(of: store.draft) { _, value in if value.count > 3000 { store.draft = String(value.prefix(3000)) }; store.save() }
                Button {
                    focused = false
                    if !store.consented { showConsent = true } else { store.send() }
                } label: { Image(systemName: "arrow.up").font(.system(size: 17, weight: .semibold)).frame(width: 38, height: 38).background(OracleTheme.accent, in: Circle()).foregroundStyle(OracleTheme.buttonInk) }
                    .disabled(!store.available || store.sending || store.hasPending || store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(store.available ? 1 : 0.4).accessibilityLabel(L10n.t("发送")).accessibilityIdentifier("tree.send")
            }.padding(14).background(OracleTheme.card, in: RoundedRectangle(cornerRadius: 24))
            AppText("AI 陪伴 · 由你选择何时分享").font(.system(size: 9)).foregroundStyle(OracleTheme.muted)
        }.padding(.horizontal, 20).padding(.vertical, 10).background(.ultraThinMaterial)
    }
    private var consentSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    AppText("聊天发送说明").font(.system(size: 26, weight: .medium))
                    AppText("发送消息时，本次输入及最近最多 10 轮对话将通过应用后端发送给模型服务商，用于生成回复。昵称、生日、星盘、问答和抽签记录不会自动随消息上传。")
                    AppText("请勿发送身份证、密码、验证码、精确住址或其他不愿分享的隐私。回复由 AI 生成，可能出错，不代替医疗、法律或其他专业服务。")
                    if !store.provider.isEmpty { AppText("模型服务商：" + store.provider) }
                    if let url = store.privacyURL { Link(L10n.t("服务商隐私政策"), destination: url) }
                    AppText("对话和草稿保存在当前本机档案内。可以在右上角菜单清空对话或撤回后续发送授权。应用参考后端不保存对话正文；模型服务商的处理与保留规则以其隐私政策为准。")
                    if store.available && !store.consented { PrimaryButton(title: "同意并开启聊天") { store.approve(); showConsent = false } }
                }.font(.system(size: 14)).lineSpacing(8).padding(25)
            }.background(OracleTheme.background).navigationTitle(L10n.t("树洞"))
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.t("完成")) { showConsent = false } } }
        }.tint(OracleTheme.accent)
    }
}

private struct FlowChips: View {
    let select: (String) -> Void
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(["有件开心的事想分享", "今天有点委屈，想吐槽", "先听我说，不用给建议", "想一起理清一个烦恼"], id: \.self) { text in
                Button { select(L10n.t(text)) } label: { AppText(text).font(.system(size: 12)).frame(maxWidth: .infinity, minHeight: 43).padding(7).warmGlass(radius: 17) }.buttonStyle(.plain)
            }
        }
    }
}

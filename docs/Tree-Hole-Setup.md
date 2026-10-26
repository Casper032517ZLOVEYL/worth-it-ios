# 树洞聊天接入

树洞位于五栏导航正中。当前未配置模型，不生成假回复；仍可写本机草稿。现有本机档案不需要手机号、邮箱或互联网账号。对话按档案隔离，最多保留最近 100 条本机消息。可以清空、停止等待、重试最后一条未回复消息，或撤回后续发送授权。

## 服务端

参考实现与现有短信 / 微信服务共用 `backend/server.py`，模型调用在 `backend/tree_hole.py`。复制 `backend/environment.example` 到自己的部署环境，填写：

- `CHAT_COMPLETIONS_URL`：模型服务的完整 HTTPS chat-completions 地址，不能含查询密钥或 URL 用户密码。
- `CHAT_MODEL`：该服务实际支持的模型 ID。
- `CHAT_API_KEY`：仅留在服务器环境。
- `CHAT_SESSION_KEY`：独立的随机秘密，至少 32 个字符，用来签署树洞专属两小时会话。
- `CHAT_PROVIDER_NAME`、`CHAT_PROVIDER_PRIVACY_URL`：真实服务商名称及 HTTPS 隐私页，发送授权前会展示。缺少隐私页时服务保持不可用。
- 共用服务现有的 `VERIFICATION_HMAC_KEY`（至少 32 字符）、数据库路径及反向代理配置；不启用短信时无需填短信凭据。

协议参考 [DeepSeek 官方 Chat Completions 文档](https://api-docs.deepseek.com/api/create-chat-completion/)，采用 `model`、`messages`、`max_tokens`、`stream=false`，读取 `choices[0].message.content`。地址与模型可更换为兼容该协议的服务；请以实际服务商当前文档填写模型名，不把示例名称当作固定可用模型。模型响应由真实 HTTPS 调用获得，没有内置模板冒充 AI。

运行前通过进程管理器注入环境，再执行 `python3 backend/server.py`。只监听 `127.0.0.1`，外部使用 HTTPS 反向代理。反向代理需覆盖并传递真实 `X-Real-IP`，然后启用 `AUTH_TRUST_LOCAL_PROXY=1`；不可直接信任外部客户端自填的地址。多实例部署应把限流迁移到共享网关 / Redis，并设置服务商消费限额。当前参考实现为每进程内存限流。

## iPhone 客户端

在已有 `Configuration/WeChat.local.xcconfig` 中配置公开地址：

```xcconfig
TREE_HOLE_BASE_URL = https:/$()/chat.your-domain.com/
```

`$()` 用于防止 xcconfig 把 `//` 当注释。**任何模型密钥都不能放入 Xcode 配置、Info.plist 或 Swift 代码。** 无需修改 ATS，也不允许 HTTP 明文服务。

## 请求链路

1. `GET /tree-hole/status`：只获取可用状态、服务商名称、隐私 URL，不带个人资料。
2. 用户阅读发送说明并同意。授权按后端地址、服务商名称、隐私页及说明版本保存；这些字段改变后需重新同意。
3. `POST /tree-hole/session`：获取限树洞用途的匿名短期令牌，不创建互联网身份、不解锁账号管理。
4. `POST /tree-hole/messages`：携带 Bearer 令牌、`consent=true` 及消息列表。仅包含用户主动输入和最近最多 10 轮上下文，不带生日、星盘、问卷、抽签或昵称。
5. 后端加入固定系统指令后调用模型。消息单条最多 3000 字，上下文最多 21 条 / 16000 字，回复最多 1200 token。会话令牌不返回模型密钥。

限制：每 IP 每小时最多申请 5 个短期会话、每分钟 8 次消息、每天 80 次消息；相同会话最多一个在途请求，模型超时 40 秒。共用 HTTP 层另有每 IP 每分钟 30 次请求限制。令牌失效会自动重新申请一次；网络失败保留待回复消息供用户手动重试。用户停止或离开页面会取消客户端等待，已到达服务商的请求未必能撤回。

## 数据与真实联调

参考后端不保存聊天正文，也不记录请求 URL、凭据和正文。服务商是否保留数据，以其真实隐私政策与账号设置为准。清空本机对话不等于删除服务商已经处理的内容。上线时需据实际服务更新公开隐私政策和平台数据申报。

目前仅完成客户端、服务端和自动测试，未部署公网服务，未配置或验证真实模型回复。部署后用真实设备检查：喜悦、只想被倾听、抱怨、需要建议、多轮上下文；拒绝授权、撤回授权、取消、断网、超时、401、429、清空和档案删除。测试里的传输替身只用于自动测试，不会进入生产链路。

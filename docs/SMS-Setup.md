# 短信验证码与账号服务配置

客户端已取消“输入手机号直接进入”。必须先由服务端发送真实短信，再用六位验证码换取应用 session。尚无短信服务、AppID 或部署域名时会明确提示暂未开放，不显示验证码、不创建登录态。邮箱入口仍是标明未验证的本机建档；账号内邮箱绑定通过真实验证邮件完成。

## 客户端

复制 `Configuration/WeChat.local.xcconfig.example` 为 `Configuration/WeChat.local.xcconfig`。仅启用短信时可只填：

```xcconfig
AUTH_BASE_URL = https:/$()/auth.your-domain.com/
```

`$()` 用来避免 xcconfig 把 `//` 当注释。必须使用 HTTPS，不要关闭 ATS。`AUTH_BASE_URL` 供全部账号接口使用，未填写时兼容旧的 `WECHAT_AUTH_BASE_URL`。只做短信时不需要配置微信 AppID、Associated Domains 或签名能力。

## 腾讯云短信

本实现对接腾讯云官方 Python SDK 的 `sms.v20210111.SendSms`。在腾讯云创建短信应用、通过短信签名与验证码模板审核，并为服务端设置：

| 环境变量 | 含义 |
|---|---|
| `TENCENT_SECRET_ID` / `TENCENT_SECRET_KEY` | 具有发送短信权限的服务端凭证，建议使用权限受限的子账号 |
| `SMS_SDK_APP_ID` | 短信应用 SDK AppID |
| `SMS_SIGN_NAME` | 已审核通过的中文签名 |
| `SMS_TEMPLATE_ID` | 已审核通过的验证码模板 ID |
| `SMS_REGION` | 默认 `ap-guangzhou` |
| `SMS_TEMPLATE_WITH_MINUTES` | 默认一个模板参数 `[验证码]`；设为 `1` 时两个参数 `[验证码, "5"]`，必须与模板一致 |
| `VERIFICATION_HMAC_KEY` | 至少 32 字符的随机服务端密钥，用于验证码摘要，不可发给客户端 |
| `AUTH_DATABASE` | SQLite 持久化路径，默认 `worthit-auth.sqlite3` |
| `PORT` | 默认 `8080` |

不要把密钥填进 Xcode 或提交 Git。配置示例在 `backend/environment.example`，自行用服务管理器注入环境；程序不会自动加载 `.env`。安装依赖并启动：

```sh
python3 -m pip install -r backend/requirements.txt
python3 backend/server.py
```

服务仅监听 `127.0.0.1`，需要自行部署 HTTPS 反向代理。默认把 TCP 连接来源作为限流来源。在单机代理后，为区分真实用户，可设置 `AUTH_TRUST_LOCAL_PROXY=1`；此时只接受回环代理传来的 `X-Real-IP`。代理必须覆盖该请求头，不能透传客户端自填值。另配置入口访问限制和短信账单告警。多实例需要共享存储及统一限流。没有配置腾讯云参数或 SDK 不可用时返回 503，不会生成可用的模拟验证码。

[腾讯云 SendSms 官方接口](https://cloud.tencent.com/document/api/382/55981) 的手机号采用 E.164；App 收集中国大陆 11 位号码，服务端发送时加 `+86`。这是发送代码接入，正式投放前仍需在自己的云账号、审核模板与域名上真机联调。

## 验证接口

| 方法 | 路径 | 请求 / 返回 |
|---|---|---|
| POST | `/auth/verification/send` | `{target:"138…",channel:"sms",purpose:"login"}` → `{challengeID,expiresAt,resendAfter}` |
| POST | `/auth/phone/verify` | `{target,challengeID,code}` → `{sessionToken,expiresAt,user}` |
| GET | `/auth/session` | Bearer session → 当前用户 |
| POST | `/auth/logout` | Bearer session + `{}` → 撤销当前 session |

验证码随机生成六位、有效期 5 分钟、最多尝试 5 次、成功后只能用一次。新验证码送达后旧验证码失效。服务端仅保存带密钥的 HMAC 摘要，不把验证码写入日志或返回 API。按收件人至少间隔 60 秒、每小时最多 5 次；每来源每小时最多 10 次；默认全局每日最多 100 次，以便首次接入控制用量。发送失败也计入频率限制。上线规模变化时应调整服务端策略。

本地重发倒计时只是交互提示，真正的限流与验证由服务端执行。会话默认 7 天，token 保存在 Keychain，服务端仅存 token 哈希。冷启动必须重新确认服务端 session，旧版未验证的手机号档案不能直接进入；相同号码完成验证后保留原本机档案与历史。

## 账号安全

以下接口均要求 Bearer session：

- 同一发送接口，`purpose` 为 `phone` / `email` / `password`。服务端将验证码绑定至当前用户、用途和目标联系方式；密码校验只允许向已绑定手机或邮箱发送。
- `POST /account/phone` / `/account/email`：`{target,challengeID,code}`。冲突的联系方式不会合并或覆盖其他账号。
- `POST /account/password`：`{challengeID,code,password}`，8–128 字符。密码以随机盐和 PBKDF2-HMAC-SHA256（600000 次）保存。当前登录界面仍使用验证码，不提供密码登录入口。
- `POST /account/bind/wechat`：`{challengeID,state,code}`，通过官方微信 code 交换绑定。需要微信单独配置。
- `POST /account/revoke-others`：`{}`，退出其他设备。
- `POST /account/delete`：`{}`，删除当前服务端账号、身份映射、密码与 session；要求最近 10 分钟内重新登录。成功后 App 删除当前本机档案、问答、抽签与任务记录。其他档案保留。

设置密码、更换手机或邮箱会撤销其他 session。苹果、微博、QQ 的入口按设计保留，目前显示暂未开放，不伪造已绑定状态。微信绑定仅在配置完成、安装微信且已有验证账号时可发起。

邮箱绑定使用 SMTP over TLS，需要 `SMTP_HOST`、`SMTP_USER`、`SMTP_PASSWORD`、`SMTP_FROM`；`SMTP_PORT` 默认 465。没有邮件通道时返回不可用。微信、手机可绑定同一服务端用户，本机历史不会因增加联系方式而被清空。

## 验证与联调

```sh
python3 -m unittest discover -s backend -v
```

自动测试用依赖注入的发送器验证逻辑，生产路径没有测试码或放行开关。Debug UI 自动化会关闭登录网络请求，避免配置完成后误向测试号码发送短信；不会伪造登录成功。覆盖重复使用、并发校验、5 次错误限制、过期、重发、发送失败、用途与用户隔离、账号绑定冲突、退出和注销。

正式联调需要验证：真实短信送达、正确/错误/过期验证码、重发冷却、断网重试、退出后重新登录、换绑和注销。尚未拥有真实服务配置，因此当前不能声称已验证实际送达。

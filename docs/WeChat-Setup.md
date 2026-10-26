# 微信登录配置

本工程已集成官方 OpenSDK **2.0.9 无支付版 XCFramework**，实现 `snsapi_userinfo` 授权请求、URL Scheme 与 Universal Link 回调、随机 state 校验、服务端 code 交换、Keychain 保存应用登录凭证、服务端登录态确认和退出撤销。未配置或未安装微信时不显示授权按钮。**当前没有真实 AppID、域名或服务端部署，因此尚未完成真机微信登录联调。**

## 1. 微信开放平台

申请并审核通过移动应用，开通微信登录权限。填写与 Xcode 一致的 Bundle ID、iOS Universal Link，并保证自己的开发团队签名及 Associated Domains 能力可用。

工程当前 Bundle ID 为 `com.casper.WorthIt.----`；如更改，开放平台、AASA 文件和签名设置必须同步。不要把 OpenID、UnionID 或填写的微信号当作客户端自己声明的可信登录身份。

## 2. Xcode 客户端配置

把 `Configuration/WeChat.local.xcconfig.example` 复制为同目录的 `WeChat.local.xcconfig`，填写真实值：

- `WECHAT_APP_ID`：移动应用的微信 AppID。
- `WECHAT_UNIVERSAL_LINK`：HTTPS 完整链接，必须以 `/` 结尾，例如 `https://links.your-domain.com/wechat/`。
- `AUTH_BASE_URL`：登录服务 HTTPS 根地址（兼容旧的 `WECHAT_AUTH_BASE_URL`）。
- `WECHAT_ASSOCIATED_DOMAIN`：`applinks:你的域名`。
- `CODE_SIGN_ENTITLEMENTS`：模板已指向 `Configuration/WeChat.entitlements`；开发团队须具备对应能力。

`.xcconfig` 中 `//` 会被解析为注释，所以模板写成 `https:/$()/...`。该写法构建后展开为正常 HTTPS URL。客户端配置文件中没有 AppSecret。

已有的 `AppInfo.plist` 会把 AppID 写入 URL Scheme，并加入 `weixin`、`weixinULAPI`、`weixinURLParamsAPI` 查询白名单。不要关闭 ATS，也不要添加任意 HTTP 访问豁免。

## 3. Universal Link 域名

在域名的 `/.well-known/apple-app-site-association` 提供 JSON 文件，内容参考 `backend/apple-app-site-association.example.json`，替换真实 Team ID 和 Bundle ID，保留 `/wechat/*` 路径通配符。用 `application/json` 返回，不要给文件名加扩展名，不要重定向。

须先验证 `https://你的域名/wechat/abc` 在真机 Safari 上能唤起此 App，再验证微信授权返回。仅修改 Xcode 配置并不能自动取得域名控制权或部署 AASA。

## 4. 服务端

`backend/server.py` 是服务端参考实现（短信使用官方腾讯云 SDK，微信交换仅用 Python 标准库）。它只监听 `127.0.0.1`，需要由你部署在 HTTPS 反向代理之后。AppSecret 通过服务端环境变量提供，不写进源码、客户端、日志或 Git。

环境变量：`WECHAT_APP_ID`、`WECHAT_APP_SECRET`、随机密钥 `VERIFICATION_HMAC_KEY`（至少 32 字符）、可选 `AUTH_DATABASE`、`PORT`。数据库默认 `worthit-auth.sqlite3`，存放服务端内部的 OpenID 与应用用户映射；应用 session token 只存哈希。部署时使用独立进程、持久卷、TLS、备份与入口限流；多实例需换用共享存储及统一限流。

接口约定：

| 方法 | 路径 | 请求 / 返回 |
|---|---|---|
| POST | `/auth/wechat/challenge` | `{}` → `challengeID`、随机 `state`、`expiresAt` |
| POST | `/auth/wechat/exchange` | `{challengeID,state,code}` → `{sessionToken,expiresAt,user:{id,nickname}}` |
| GET | `/auth/session` | `Authorization: Bearer 应用token` → `{id,nickname}` |
| POST | `/auth/logout` | 相同 Bearer token，`{}` → `{id,nickname}` 并撤销 token |

state 有效期 5 分钟且只能消费一次；应用 session 有效期 7 天。服务端使用自己的固定 AppID 和 AppSecret 向微信交换 code，不信任客户端传来的用户 ID。当前只需要登录身份，因此不额外请求用户资料，微信 access_token 与 refresh_token 不返回客户端，也不持久化。昵称在应用内自行设置。

测试不访问真实微信：

```sh
python3 -m unittest discover -s backend -v
```

## 5. 真机联调

安装微信并使用正确团队签名运行 App。在注册界面阅读并勾选说明，再点微信授权。验证允许、取消、拒绝、超时、重复回调和断网情况；冷启动时也要能用 Universal Link 返回，退出后需重新授权。模拟器无法替代微信真机授权测试。

服务端收到 code 后才交换凭证；取消、失败、state 不匹配或服务端验证失败，都不会让用户进入微信档案。出生信息、答题、小任务和决定簿仍仅存在本机，不包含在登录请求里。手机号现需真实短信验证，配置见 [短信与账号接入](SMS-Setup.md)。邮箱入口仍是本机建档；在账号安全中绑定邮箱需真实邮件验证。

## 官方来源与 SDK

- [移动应用微信登录开发指南](https://developers.weixin.qq.com/doc/oplatform/Mobile_App/WeChat_Login/Development_Guide.html)
- [iOS 接入指南](https://developers.weixin.qq.com/doc/oplatform/Mobile_App/Access_Guide/iOS.html)
- [官方资源下载](https://developers.weixin.qq.com/doc/oplatform/Mobile_App/Downloads/iOS_Resource.html)
- [本工程使用的无支付版下载](https://dldir1.qq.com/WechatWebDev/opensdk/XCFramework/OpenSDK2.0.9_NoPay.zip)

下载包 SHA-256：`ae8c7e847d83997f38891e27ad6bed98dd50d638a00ef2ec0890d4e9ac748f83`。

SDK 位于 `Vendor/WechatOpenSDK-NoPay.xcframework`，保留官方头文件、二进制、README 和隐私清单。两个 slice 的 `module.modulemap` 中将 `link "WechatOpenSDK"` 更正为 `link framework "WechatOpenSDK"`，以避免框架被当作同名 `.a` 自动链接；这是一项本地模块描述修正，SDK 二进制未修改。静态链接补全了 C++、zlib、sqlite 及官方要求的系统框架。根隐私清单已一并复制到应用资源中；发布前仍须结合实际部署填写隐私声明。

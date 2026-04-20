# Universal Links 发布清单

这份清单用于把学生端的“单 App 多学校入口”做成真正可发布的 Universal Links / App Links 方案。

## 默认入口规则

- 学校专属入口：`https://english.201807.xyz/s/<school_code>`
- App 内路由：`/s/:schoolCode`
- 兜底查询参数：`https://english.201807.xyz/app?school=<school_code>`

## 已落到代码里的配置

- iOS Associated Domains entitlements：
  - `ios/Runner/Runner.entitlements`
- iOS 构建变量：
  - `ios/Runner.xcodeproj/project.pbxproj`
  - 默认 `APP_LINK_HOST = english.201807.xyz`
- Android App Links：
  - `android/app/src/main/AndroidManifest.xml`
  - `android/app/build.gradle.kts`
- Flutter 应用内链接监听：
  - `lib/features/school/presentation/widgets/school_link_listener.dart`
- 服务端静态文件模板：
  - `web/.well-known/apple-app-site-association`
  - `web/.well-known/assetlinks.json`

## 上线前必须替换的值

### iOS

- 如果 Apple Team ID 或 bundle id 发生变化，同步更新：
  - `web/.well-known/apple-app-site-association`

### Android

- 把 `web/.well-known/assetlinks.json` 里的：
  - `REPLACE_WITH_RELEASE_SHA256_FINGERPRINT`
  替换成正式签名包的 SHA256 指纹。

## 域名部署要求

正式域名 `english.201807.xyz` 下必须能直接访问：

- `https://english.201807.xyz/.well-known/apple-app-site-association`
- `https://english.201807.xyz/.well-known/assetlinks.json`

要求：

- `apple-app-site-association` 不带 `.json` 后缀
- 返回 `200`
- `Content-Type` 建议是 `application/json`
- 不要走登录态、302 跳转或鉴权

## App Store / TestFlight 前验收

1. 真机安装 Debug / TestFlight 包
2. 用 Safari 打开：
   - `https://english.201807.xyz/s/claremont-demo`
3. 确认会直接唤起 App
4. App 内应自动进入对应学校上下文，不需要手输邀请码
5. 如果账号绑定多个学校，仍然以链接里的学校为优先入口

## 回归测试建议

- 已安装 App：点击学校链接，直接进 App
- 未安装 App：先落网页，再引导下载
- App 在前台时再次点链接：应跳到新的学校入口
- 多学校账号：链接优先，平时登录按账号自动选校

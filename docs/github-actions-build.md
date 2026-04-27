# GitHub Actions 构建说明

这套工作流对应文件：

- [flutter-build.yml](/Volumes/移动磁盘/peixun%20/student_app/.github/workflows/flutter-build.yml)

## 当前支持的构建

- Android `release apk`
- Android `release aab`
- iOS `unsigned build`（手动触发，可用于检查 iOS 工程是否能编译，不可直接上架）

## 当前发布优先级

- 当前主线：**Android 发布**
- iOS：**后期整理**

原因是 iOS 仍缺 Apple Developer Program 会员、Team ID 和正式签名链路；因此当前 CI、签名和提测工作优先围绕 Android 收口。

## 触发方式

### 自动触发

- 推送到 `main`
- 推送 tag，例如 `v1.0.0`

### 手动触发

进入 GitHub 仓库：

1. `Actions`
2. 选择 `Flutter Build`
3. 点 `Run workflow`
4. 如果只是当前安卓发布，可以不勾 `build_ios`
5. 如果后期要顺手检查 iOS 编译，再把 `build_ios` 设为 `true`

## 需要配置的 GitHub Secrets

进入仓库：

1. `Settings`
2. `Secrets and variables`
3. `Actions`
4. 新建下面几个 Secret

### 必填

- `SUPABASE_URL`
  - 值：`https://ckgiwlblwkzenkxkbujx.supabase.co`
- `SUPABASE_PUBLISHABLE_KEY`
  - 值：你的 `sb_publishable_...`

### 可选

- `APP_DATA_MODE`
  - 默认就是 `supabase`
  - 如果不填，工作流会自动写成 `supabase`

### 内部 QA 专用

- `ALLOW_RELEASE_MOCK_DATA`
  - 默认不要配置
  - 只有需要构建“Release 形态 + Mock 数据”的内部 QA 包时才允许设置为 `true`
  - 正式上线包必须保持为空或 `false`

### Android 正式签名可选 Secret

如果你要让 GitHub Actions 直接产出正式签名的 Android 包，再补下面几个：

- `ANDROID_KEYSTORE_BASE64`
  - 把你的 `upload-keystore.jks` 做 base64 编码后的内容
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_STORE_PASSWORD`

只要这 4 个 Secret 都配置好，工作流会自动写入 `android/key.properties` 并使用正式签名；如果不配，就继续回退到 debug signing。

## 产物在哪里看

每次 Action 跑完后，进入对应 workflow run 页面，在底部 `Artifacts` 下载：

- `android-build-*`
  - 包含 `app-release.apk`
  - 包含 `app-release.aab`
- `ios-unsigned-build-*`
  - 包含 `Runner.app.zip`

## 当前限制

### Android

当前已经支持两种模式：

- 没配置 Android 签名 Secret：用 debug signing 构建，只适合内部测试
- 配置了 Android 签名 Secret：自动产出正式签名的 `apk` 和 `aab`

### iOS

当前只做 `--no-codesign` 构建，所以：

- 能验证 iOS 工程是否可编译
- 不能直接生成可安装/可上架的正式 IPA

正式上架前还需要补：

- Apple 证书
- Provisioning Profile
- 签名与导出流程
- 正式 Bundle Identifier
- Apple Developer Program Team ID

## 建议的下一步

建议按这个顺序推进：

1. 先把仓库推到 GitHub
2. 先配置：
   - `SUPABASE_URL`
   - `SUPABASE_PUBLISHABLE_KEY`
3. 先手动跑一次 `Flutter Build`，确认 `flutter analyze --no-fatal-infos`、`flutter test` 和 Android `apk/aab` 能正常产出
4. 再补 Android keystore 的 4 个 Secret，切到正式签名包
5. iOS 暂时只保留工程可编译检查，不作为当前发布阻塞项

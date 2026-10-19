# iOS TestFlight

推到 `main` 且改动 `codes/ios/**` 时，`.github/workflows/ios-testflight.yml` 会在 `macos-latest` 上归档 scheme `sky-wanderer`（iPhone，并嵌入 Watch）并上传 TestFlight。Actions 里也可以手动 Run workflow（`workflow_dispatch`）。同一时间只跑一个上传，不会取消已经开始的那次。

只改工作流文件不会自动触发（path 只包含 `codes/ios/**`）。

## 第一次运行

仓库里没有证书和 API 密钥。**第一次成功上传之前，需要仓库管理员**在 GitHub → Settings → Secrets and variables → Actions 配好下表。缺任何一个，工作流会在签名前退出，并且不会打印密钥的值。

配好之后，可以在 Actions 里对包含该工作流的分支手动运行，或等下一次 `main` 上的 iOS 改动。

## Xcode

截至 2026-10-19，`macos-latest` 是 macOS 26（arm64）。该镜像里最新的非 beta Xcode 是 **26.6**，自带 iOS 26.5 SDK。

工程部署目标是 iOS 26.0，落在 Xcode 26.6 支持的 iOS 15–26.5 里；手表是 watchOS 10，落在 watchOS 8–26.5 里。**Runner 上的 Xcode 不是过旧。** 工作流会选镜像里版本 ≥ 26 的最新非 beta Xcode，并在 SDK 低于 26 时失败。

单独的 `xcode-27` 镜像更新，但这个部署目标不需要它。

## Secrets

| Secret | 值 |
| --- | --- |
| `ASC_ISSUER_ID` | App Store Connect → 用户和访问 → 集成 → App Store Connect API 的 Issuer ID |
| `ASC_KEY_ID` | 该 API 密钥的 Key ID |
| `ASC_API_KEY_P8` | 下载的 `AuthKey_XXXX.p8` 全文（PEM）。页面只提供一次下载 |
| `BUILD_CERTIFICATE_BASE64` | Apple Distribution 证书的 `.p12`，做 base64。角色需要能管理证书和描述文件（Admin 或 App Manager） |
| `P12_PASSWORD` | 导出该 p12 时设的密码 |
| `BUILD_PROVISION_PROFILE_BASE64` | `com.rongxuning.sky-wanderer` 的 **App Store** 描述文件（`.mobileprovision` 的 base64） |
| `BUILD_PROVISION_PROFILE_WATCH_BASE64` | `com.rongxuning.sky-wanderer.watchkitapp` 的 **App Store** 描述文件 |
| `APPLE_TEAM_ID` | `QTV9DUCAY7` |

API 密钥、证书和两个描述文件要属于同一个团队。两个 App ID 都要打开 HealthKit，和仓库里的 entitlements 一致。

在 Mac 上生成 base64（换行会被去掉，带换行也可以）：

```bash
base64 -i distribution.p12 | tr -d '\n'
base64 -i sky-wanderer-appstore.mobileprovision | tr -d '\n'
base64 -i sky-wanderer-watch-appstore.mobileprovision | tr -d '\n'
```

## 签名

用手动签名，和装进 runner 的描述文件一致。iPhone 与 Watch 的 bundle id 不同，**一份描述文件盖不住两个目标**，所以手表是单独的 secret，没有合并方案。

描述文件会装到 `~/Library/MobileDevice/Provisioning Profiles/`，并复制一份到 `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`。p12 只进临时钥匙串。这些文件在 job 结束时删掉。

## 版本号

CI **不会**把版本号提交回仓库。

- `MARKETING_VERSION`：沿用工程里的值（现在是 `1.0`）。两个 target 不一致时，这次归档用较高的那个，不会降回 `1.0`，也不会自动加营销版本。要上新版本时，在 Xcode 工程里改。
- `CFBundleVersion` / `CURRENT_PROJECT_VERSION`：用 ASC API 查这个营销版本已有的构建号，取最大的再 +1。还没有任何构建时用 `1`。上次手动上传是 `1.0` (`1`)，所以第一次成功的自动构建应是 `2`（以 ASC 上的记录为准）。查询遇到网络错误或 HTTP 5xx 时，退回 `github.run_number`。认证失败（401/403）会直接停下，避免用错构建号再传一次。
- 构建号通过本次 `xcodebuild` 的 build setting 传入，并只在 job 的工作区里改 Release 配置。工程没有打开 `apple-generic` versioning，所以不用 `agvtool`。job 结束会把 `project.pbxproj` 还原。

## 上传

导出 IPA（`app-store-connect` + `destination=export`）后，用 `xcrun altool --upload-app`。当前 Xcode 没有 altool 时改用 `xcrun iTMSTransporter`。API 密钥写到 `~/private_keys/AuthKey_<ASC_KEY_ID>.p8`。

上传成功后，按 bundle id `com.rongxuning.sky-wanderer` 查找这个构建号，最多等约 3 分钟，然后 `PATCH` `usesNonExemptEncryption=false`。处理若还没开始，这一步会是警告，**IPA 已经在 App Store Connect**；TestFlight 若仍询问出口合规，在网页上补一次即可。不要为了补合规再跑整条工作流，否则会再上传一个新构建。

## ASC 90112

iPhone 的 `codes/ios/sky-wanderer/Info.plist` 已去掉整个 `UIBackgroundModes`（里面是 `workout-processing`，iOS 上无效）。手表 `codes/ios/sky-wanderer-watch/Info.plist` 的 `WKBackgroundModes` 保留。

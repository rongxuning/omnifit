# omnifit

iPhone 和 Apple Watch 上的徒步、跑步应用。用 Xcode 16 或更新版本打开 `Omnifit.xcodeproj`。部署目标是 iOS 17 和 watchOS 10。

这台开发环境不能编译 Apple 平台，仓库里的工程没有在这里跑过构建。请在 Mac 上用 Xcode 编译 iPhone 和 Watch 两个 scheme。签名时选自己的开发团队。HealthKit 能力要在开发者账号里打开；仓库里的 entitlements 只是占位，没有密钥。

Bundle ID：`com.rongxuning.omnifit`，手表是 `com.rongxuning.omnifit.watchkitapp`。

## 真实和模拟

真实路径：HealthKit 授权后读取心率、睡眠、步数，并记录徒步和跑步；地图用 MapKit 和系统定位；账号存在本机。

模拟路径：没有 HealthKit 或锻炼启动失败时，运动数据在本机生成，界面会写「本地模拟」。组队没有服务器，`LocalTeammateSimulator` 按 `TeammateSync` 在本机移动示例队友。忘记密码不发邮件，页面上会给出演示验证码 `OMNI-LOCAL`，没有位数和有效期。社交示例帖和示例训练记录是本地种子数据。手表和手机的记录各自存在本机，没有同步。手表上的社交、组队、我、周/月/年统计是更短的一版，没有手机上的密图表。

训练负荷、体能储备、休息建议的公式在 `Shared/TrainingEstimate.swift`。图表 Z1–Z5 的分界在 `Shared/ZoneScale.swift`，只用于着色，不是医疗标准。

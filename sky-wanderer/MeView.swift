import SwiftUI

struct MeView: View {
    @EnvironmentObject private var app: PhoneAppState
    @StateObject private var health = MeHealth()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("个人设置")
                    .font(.system(size: 32, weight: .bold, design: .rounded))

                sectionTitle("账号")
                HStack {
                    Text(app.account?.name ?? "")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                    Spacer()
                    Text("已登录")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.omniCobalt)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.omniIce.opacity(0.35), in: Capsule())
                }
                .padding(16)
                .glass()

                sectionTitle("健康")
                if !health.note.isEmpty {
                    Text(health.note)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.omniMuted)
                }
                VStack(spacing: 0) {
                    healthRow("心率", value: "\(Int(health.heartRate.rounded()))", unit: "次/分", sample: health.heartIsSample, coral: true)
                    healthRow("睡眠", value: String(format: "%.1f", health.sleepHours), unit: "小时", sample: health.sleepIsSample, coral: false)
                    healthRow("步数", value: "\(health.steps)", unit: "步", sample: health.stepsAreSample, coral: false)
                }
                .glass()

                sectionTitle("训练估计，不是医疗建议")
                VStack(alignment: .leading, spacing: 12) {
                    estimateRow("体能储备", "\(app.estimate.reserve)")
                    estimateRow("训练负荷", "\(app.estimate.recentLoad)")
                    estimateRow("休息时间建议", app.estimate.restHint)
                    Text("近 7 日负荷来自每次的时长和平均心率。这是训练估计，不是医疗建议。")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.omniMuted)
                }
                .padding(16)
                .glass()

                sectionTitle("展示")
                NavigationLink(value: MeRoute.layout) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("调整展示位置")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                            Text("运动中的数据顺序")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.omniMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Color.omniIdle)
                    }
                    .foregroundStyle(Color.omniInk)
                    .padding(16)
                    .glass()
                }
                .buttonStyle(.plain)

                Button {
                    app.logout()
                } label: {
                    Text("退出登录")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.omniCobalt)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 120)
        }
        .background(CanvasBackground())
        .navigationBarHidden(true)
        .task {
            await health.refresh()
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(Color.omniMuted)
    }

    private func healthRow(_ title: String, value: String, unit: String, sample: Bool, coral: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.omniMuted)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(coral ? Color.omniCoral : Color.omniIce)
                    Text(unit)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.omniMuted)
                }
            }
            Spacer()
            if sample {
                Text("示例")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.omniCobalt)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func estimateRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Spacer()
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.omniCobalt)
        }
    }
}

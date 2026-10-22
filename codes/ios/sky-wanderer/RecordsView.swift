import SwiftUI

struct RecordsView: View {
    @EnvironmentObject private var app: PhoneAppState
    @State private var window: StatsWindow = .week

    var body: some View {
        VStack(spacing: 0) {
            statsModule
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if !app.banner.isEmpty {
                        Text(app.banner)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.omniMuted)
                    }
                    if app.workouts.isEmpty {
                        Text("还没有徒步或跑步记录")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.omniMuted)
                            .padding(.top, 12)
                    }
                    ForEach(groups) { group in
                        Text(group.title)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.omniMuted)
                            .padding(.top, 6)
                        ForEach(group.items) { workout in
                            NavigationLink(value: RecordRoute.detail(workout.id)) {
                                RecordCard(workout: workout)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 120)
            }
            .refreshable {
                await app.importFromApple()
            }
        }
        .background(CanvasBackground())
        .navigationBarHidden(true)
        .task {
            await app.importFromApple()
        }
    }

    private var stats: TrainingStats {
        app.stats(for: window)
    }

    private var statsModule: some View {
        HStack(alignment: .center, spacing: 12) {
            windowColumn
            statsGrid
        }
        .padding(14)
        .background(Color.omniDeep, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black, lineWidth: 2)
        )
        .shadow(color: Color.omniInk.opacity(0.16), radius: 14, y: 8)
    }

    private var windowColumn: some View {
        VStack(spacing: 6) {
            ForEach(StatsWindow.allCases) { item in
                let selected = window == item
                Button {
                    window = item
                } label: {
                    Text(item.rawValue)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(selected ? Color.omniDeep : Color.white.opacity(0.82))
                        .frame(width: 48, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selected ? Color.white : Color.white.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(selected ? Color.black : Color.white.opacity(0.35), lineWidth: selected ? 1.5 : 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
            Text("\(stats.count) 次")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.88))
                .padding(.top, 2)
        }
    }

    private var statsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            stat("总距离 (公里)", Format.kilometers(stats.distanceMeters), coral: false)
            stat("平均心率 (次/分)", Format.integer(stats.averageHeartRate), coral: true)
            stat("总爬升 (米)", stats.elevationGainMeters > 0 ? String(Int(stats.elevationGainMeters.rounded())) : "—", coral: false)
            stat("平均步频 (步/分)", Format.integer(stats.averageCadence), coral: false)
            stat("平均配速 (分/公里)", Format.pace(stats.averagePaceSecPerKm), coral: false)
            stat("平均步幅 (厘米)", strideText, coral: false)
            stat("平均负荷", loadText, coral: false)
        }
    }

    private var strideText: String {
        guard stats.averageStrideMeters > 0 else { return "—" }
        return Format.integer(stats.averageStrideMeters * 100)
    }

    private var loadText: String {
        guard stats.count > 0 else { return "—" }
        return String(Int(stats.averageSessionLoad.rounded()))
    }

    private func stat(_ title: String, _ value: String, coral: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.86))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(coral ? Color.omniCoral : Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var groups: [MonthGroup] {
        var result: [MonthGroup] = []
        for workout in app.workouts {
            let title = Format.monthTitle(workout.start)
            if let index = result.firstIndex(where: { $0.title == title }) {
                result[index].items.append(workout)
            } else {
                result.append(MonthGroup(id: title, title: title, items: [workout]))
            }
        }
        return result
    }
}

private struct MonthGroup: Identifiable {
    var id: String
    var title: String
    var items: [WorkoutRecord]
}

private struct RecordCard: View {
    var workout: WorkoutRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(workout.sport.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Spacer(minLength: 8)
                Text(Format.kilometers(workout.distanceMeters))
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.omniIce)
                Text("公里")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.omniMuted)
            }
            Text("\(Format.dayTime(workout.start)) · \(Format.duration(workout.duration))")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.omniMuted)
                .lineLimit(1)
            HStack(spacing: 6) {
                stat(Format.pace(workout.averagePaceSecPerKm), "配速", coral: false)
                stat("\(Int(workout.energyKilocalories.rounded()))", "千卡", coral: true)
                stat(Format.integer(workout.averageHeartRate), "心率", coral: true)
                stat("\(workout.sessionLoad)", "负荷", coral: false)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glass()
    }

    private func stat(_ value: String, _ title: String, coral: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(coral ? Color.omniCoral : Color.omniIce)
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.omniMuted)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

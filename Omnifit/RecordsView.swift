import SwiftUI

struct RecordsView: View {
    @EnvironmentObject private var app: PhoneAppState
    @State private var window: StatsWindow = .week

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("训练记录")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Picker("范围", selection: $window) {
                    ForEach(StatsWindow.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                statsCard
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
            .padding(.top, 16)
            .padding(.bottom, 120)
        }
        .background(CanvasBackground())
        .navigationBarHidden(true)
        .refreshable {
            await app.importFromApple()
        }
        .task {
            await app.importFromApple()
        }
    }

    private var stats: TrainingStats {
        app.stats(for: window)
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(window.rawValue) · \(stats.count) 次")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.omniMuted)
            HStack {
                stat("总距离", Format.kilometers(stats.distanceMeters), "公里", coral: false)
                stat("平均心率", Format.integer(stats.averageHeartRate), "次/分", coral: true)
            }
            HStack {
                stat("总爬升", stats.elevationGainMeters > 0 ? String(Int(stats.elevationGainMeters.rounded())) : "—", "米", coral: false)
                stat("平均步频", Format.integer(stats.averageCadence), "步/分", coral: false)
            }
        }
        .padding(16)
        .glass()
    }

    private func stat(_ title: String, _ value: String, _ unit: String, coral: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.omniMuted)
            Text(value)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(coral ? Color.omniCoral : Color.omniIce)
            Text(unit)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.omniMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

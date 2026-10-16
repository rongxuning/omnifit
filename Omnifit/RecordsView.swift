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
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.sport.title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                    Text(Format.dayTime(workout.start))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.omniMuted)
                    Text(Format.duration(workout.duration))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.omniMuted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(Format.kilometers(workout.distanceMeters))
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.omniIce)
                    Text("公里")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.omniMuted)
                }
            }
            Divider().overlay(Color.omniIce.opacity(0.35))
            HStack {
                mini("能量消耗", "\(Int(workout.energyKilocalories.rounded()))", "千卡", symbol: "flame.fill", coral: true)
                mini("平均心率", Format.integer(workout.averageHeartRate), "次/分", symbol: "heart.fill", coral: true)
                mini("负荷", "\(workout.sessionLoad)", "", symbol: nil, coral: false)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glass()
    }

    private func mini(_ title: String, _ value: String, _ unit: String, symbol: String?, coral: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.omniCoral)
                }
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.omniMuted)
                    .lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(coral ? Color.omniCoral : Color.omniIce)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.omniMuted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

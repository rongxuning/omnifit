import Charts
import SwiftUI

struct WorkoutDetailView: View {
    @EnvironmentObject private var app: PhoneAppState
    @Environment(\.dismiss) private var dismiss
    var workoutID: UUID

    private var workout: WorkoutRecord? {
        app.workouts.first { $0.id == workoutID }
    }

    var body: some View {
        ScrollView {
            if let workout {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        RouteMap(route: workout.route, cornerRadius: 0)
                            .frame(height: 248)
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.omniInk)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                        .padding(.leading, 8)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(workout.sport.title)  \(Format.dayTime(workout.start))–\(Format.time(workout.end))")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                            if workout.origin != .apple {
                                Text(workout.origin == .sample ? "示例数据" : "本地模拟")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.omniCobalt)
                            }
                        }
                        summary(workout)
                        splits(workout)
                        chart("心率", subtitle: "平均 \(Format.integer(workout.averageHeartRate)) 次/分", points: workout.heartRate, heart: true, zone: ZoneScale.heart)
                        chart("步频", subtitle: "平均 \(Format.integer(workout.averageCadence)) 步/分", points: workout.cadenceSeries, heart: false, zone: ZoneScale.cadence)
                        chart("配速", subtitle: "平均 \(Format.pace(workout.averagePaceSecPerKm)) 每公里", points: workout.paceSeries, heart: false, zone: ZoneScale.pace)
                        chart("步幅", subtitle: average(workout.stride, unit: "米", digits: 2), points: workout.stride, heart: false, zone: ZoneScale.stride)
                        elevationChart(workout)
                        chart("触底时间", subtitle: average(workout.groundContact, unit: "毫秒", digits: 0), points: workout.groundContact, heart: false, zone: ZoneScale.groundContact)
                        chart("功率", subtitle: average(workout.power, unit: "瓦", digits: 0), points: workout.power, heart: false, zone: ZoneScale.power)
                        Text("图上的 Z1–Z5 只用于着色，是草稿，不是医疗标准。")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.omniMuted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            } else {
                Text("找不到这次训练")
                    .padding(24)
            }
        }
        .background(Color.omniCanvas)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func summary(_ workout: WorkoutRecord) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3), spacing: 16) {
            cell("距离", Format.kilometers(workout.distanceMeters), "公里", coral: false)
            cell("配速", Format.pace(workout.averagePaceSecPerKm), "每公里", coral: false)
            cell("时长", Format.duration(workout.duration), "", coral: false)
            cell("能量消耗", "\(Int(workout.energyKilocalories.rounded()))", "千卡", coral: true)
            cell("平均心率", Format.integer(workout.averageHeartRate), "次/分", coral: true)
            cell("负荷", "\(workout.sessionLoad)", "", coral: false)
        }
        .padding(16)
        .glass()
    }

    private func cell(_ title: String, _ value: String, _ unit: String, coral: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                if coral {
                    Image(systemName: title == "平均心率" ? "heart.fill" : "flame.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.omniCoral)
                }
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.omniMuted)
            }
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(coral ? Color.omniCoral : Color.omniIce)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.omniMuted)
            }
        }
    }

    private func splits(_ workout: WorkoutRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("每公里")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
            if workout.splits.isEmpty {
                Text("这次没有每公里数据")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.omniMuted)
            } else {
                HStack {
                    Text("公里").frame(width: 48, alignment: .leading)
                    Text("配速").frame(maxWidth: .infinity, alignment: .leading)
                    Text("步频").frame(maxWidth: .infinity, alignment: .leading)
                    Text("心率").frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.omniMuted)
                ForEach(workout.splits) { split in
                    HStack {
                        Text(split.partial ? "\(split.index) 未满" : "\(split.index)")
                            .frame(width: 48, alignment: .leading)
                        Text(Format.pace(split.paceSecPerKm))
                            .foregroundStyle(Color.omniCobalt)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(Format.integer(split.cadence))
                            .foregroundStyle(Color.omniIce)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(Format.integer(split.heartRate))
                            .foregroundStyle(Color.omniCoral)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                }
            }
        }
        .padding(16)
        .glass()
    }

    private func chart(_ title: String, subtitle: String, points: [SeriesPoint], heart: Bool, zone: @escaping (Double) -> TrainingZone) -> some View {
        ZoneChartCard(title: title, subtitle: subtitle, points: points, heart: heart, zone: zone)
    }

    private func elevationChart(_ workout: WorkoutRecord) -> some View {
        let values = workout.elevation.map(\.value)
        let low = values.min() ?? 0
        let high = values.max() ?? 0
        return ZoneChartCard(title: "垂直高度", subtitle: "累计爬升 \(Int(workout.elevationGainMeters.rounded())) 米", points: workout.elevation, heart: false) { value in
            ZoneScale.elevation(value, low: low, high: high)
        }
    }

    private func average(_ points: [SeriesPoint], unit: String, digits: Int) -> String {
        guard !points.isEmpty else { return "这次没有采集到" }
        let value = points.map(\.value).reduce(0, +) / Double(points.count)
        return "平均 \(String(format: "%.\(digits)f", value)) \(unit)"
    }
}

private struct ZoneChartCard: View {
    var title: String
    var subtitle: String
    var points: [SeriesPoint]
    var heart: Bool
    var zone: (Double) -> TrainingZone

    private var shown: [SeriesPoint] {
        guard points.count > 48 else { return points }
        let step = max(1, points.count / 40)
        return points.enumerated().compactMap { index, point in
            index % step == 0 || index == points.count - 1 ? point : nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
            Text(subtitle)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.omniMuted)
            if shown.count < 2 {
                Text("这次没有采集到")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.omniMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 72)
            } else {
                Chart(shown) { point in
                    LineMark(
                        x: .value("秒", point.second),
                        y: .value(title, point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(heart ? Color.omniCoral.opacity(0.45) : Color.omniCobalt.opacity(0.4))
                    PointMark(
                        x: .value("秒", point.second),
                        y: .value(title, point.value)
                    )
                    .foregroundStyle(ZoneScale.color(zone(point.value), heart: heart))
                    .symbolSize(22)
                }
                .frame(height: 140)
                .chartXAxis(.hidden)
                HStack(spacing: 8) {
                    ForEach(TrainingZone.allCases) { item in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(ZoneScale.color(item, heart: heart))
                                .frame(width: 8, height: 8)
                            Text(item.title)
                        }
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.omniMuted)
                    }
                }
            }
        }
        .padding(16)
        .glass()
        .padding(.top, 4)
    }
}

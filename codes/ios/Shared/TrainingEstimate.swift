import Foundation

struct TrainingEstimateSummary: Equatable {
    var reserve: Int
    var recentLoad: Int
    var restHint: String
}

enum TrainingEstimate {
    /// 训练估计，不是医疗建议。
    ///
    /// 单次负荷 = 时长（分钟）×（平均心率 / 180）× 运动系数，四舍五入成整数。
    /// 运动系数：跑步 1.0，徒步 0.8。
    /// 平均心率缺失或不是正数时，这一次负荷记为 0，不用假设心率去补。
    ///
    /// 近 7 日负荷 = 开始时间落在过去 7×24 小时里的单次负荷之和。
    /// 体能储备 = max(0, 100 − 近 7 日负荷 / 5)。100 表示这 7 天没有负荷。
    /// 休息时间建议：
    /// - 近 7 日负荷 ≥ 350 → 建议休息 48 小时
    /// - 近 7 日负荷 ≥ 200 → 建议休息 24 小时
    /// - 否则 → 可以正常训练
    static func sessionLoad(duration: TimeInterval, averageHeartRate: Double, sport: SportKind) -> Int {
        guard duration > 0, averageHeartRate > 0 else { return 0 }
        let minutes = duration / 60
        let raw = minutes * (averageHeartRate / 180) * sport.loadFactor
        return Int(raw.rounded())
    }

    static func summarize(workouts: [WorkoutRecord], now: Date = Date()) -> TrainingEstimateSummary {
        let cutoff = now.addingTimeInterval(-7 * 24 * 60 * 60)
        let recent = workouts.reduce(0) { partial, workout in
            guard workout.start >= cutoff else { return partial }
            return partial + workout.sessionLoad
        }
        let reserve = max(0, 100 - recent / 5)
        let hint: String
        if recent >= 350 {
            hint = "建议休息 48 小时"
        } else if recent >= 200 {
            hint = "建议休息 24 小时"
        } else {
            hint = "可以正常训练"
        }
        return TrainingEstimateSummary(reserve: reserve, recentLoad: recent, restHint: hint)
    }
}

enum RecordStats {
    /// 平均配速 = 有距离记录的总时长 / 总公里，不是各次配速的算术平均。
    /// 平均步幅 = 各次 `averageStrideMeters` 的时长加权平均；单次没有步幅序列时，用速度和步频推算。
    /// 健康导入经常没有步幅和步频，这时平均步幅为 0，界面显示「—」。
    /// 平均负荷 = 窗口内各次负荷的算术平均，包含负荷为 0 的记录。
    static func make(workouts: [WorkoutRecord], window: StatsWindow, now: Date = Date()) -> TrainingStats {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        let matched = workouts.filter { workout in
            switch window {
            case .week:
                return calendar.isDate(workout.start, equalTo: now, toGranularity: .weekOfYear)
            case .month:
                return calendar.isDate(workout.start, equalTo: now, toGranularity: .month)
            case .year:
                return calendar.isDate(workout.start, equalTo: now, toGranularity: .year)
            }
        }
        guard !matched.isEmpty else { return .empty }
        let heartPool = matched.filter { $0.averageHeartRate > 0 }
        let cadencePool = matched.filter { $0.averageCadence > 0 }
        let heartDuration = heartPool.reduce(0) { $0 + $1.duration }
        let cadenceDuration = cadencePool.reduce(0) { $0 + $1.duration }
        let heart = heartDuration > 0 ? heartPool.reduce(0) { $0 + $1.averageHeartRate * $1.duration } / heartDuration : 0
        let cadence = cadenceDuration > 0 ? cadencePool.reduce(0) { $0 + $1.averageCadence * $1.duration } / cadenceDuration : 0
        let moving = matched.filter { $0.distanceMeters > 1 && $0.duration > 0 }
        let movingDistance = moving.reduce(0) { $0 + $1.distanceMeters }
        let movingDuration = moving.reduce(0) { $0 + $1.duration }
        let pace = movingDistance > 1 ? movingDuration / (movingDistance / 1000) : 0
        let stridePool = matched.filter { $0.averageStrideMeters > 0 && $0.duration > 0 }
        let strideDuration = stridePool.reduce(0) { $0 + $1.duration }
        let stride = strideDuration > 0
            ? stridePool.reduce(0) { $0 + $1.averageStrideMeters * $1.duration } / strideDuration
            : 0
        let load = Double(matched.reduce(0) { $0 + $1.sessionLoad }) / Double(matched.count)
        return TrainingStats(
            distanceMeters: matched.reduce(0) { $0 + $1.distanceMeters },
            averageHeartRate: heart,
            elevationGainMeters: matched.reduce(0) { $0 + $1.elevationGainMeters },
            averageCadence: cadence,
            count: matched.count,
            averagePaceSecPerKm: pace,
            averageStrideMeters: stride,
            averageSessionLoad: load
        )
    }
}

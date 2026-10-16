import CoreLocation
import Foundation
import HealthKit

/// Brand extension point. Phase 1 only builds `AppleActivitySource`.
/// A later brand implements this and is constructed beside Apple — the views
/// read workouts, they do not talk to HealthKit directly.
protocol ActivitySource {
    var brandName: String { get }
    func prepare() async throws
    func importRunsAndHikes() async throws -> [WorkoutRecord]
}

struct AppleActivitySource: ActivitySource {
    var brandName: String { "Apple" }

    func prepare() async throws {
        try await AppleHealth.authorize()
    }

    func importRunsAndHikes() async throws -> [WorkoutRecord] {
        try await AppleHealth.importRunsAndHikes()
    }
}

struct DayHealth: Equatable {
    var heartRate: Double?
    var sleepHours: Double?
    var steps: Int?
}

enum RecorderError: Error {
    case unavailable
    case failed
}

enum AppleHealth {
    static let store = HKHealthStore()
    static var available: Bool { HKHealthStore.isHealthDataAvailable() }

    static func authorize() async throws {
        guard available else { throw RecorderError.unavailable }
        try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    static func importRunsAndHikes() async throws -> [WorkoutRecord] {
        guard available else { return [] }
        let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                HKQuery.predicateForWorkouts(with: .running),
                HKQuery.predicateForWorkouts(with: .hiking)
            ])
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: HKWorkoutType.workoutType(),
                predicate: predicate,
                limit: 80,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }
        var records: [WorkoutRecord] = []
        for workout in workouts {
            guard let sport = SportKind.from(workout.workoutActivityType) else { continue }
            let route = await routePoints(for: workout)
            records.append(record(from: workout, sport: sport, route: route))
        }
        return records
    }

    static func today() async -> DayHealth {
        guard available else { return DayHealth(heartRate: nil, sleepHours: nil, steps: nil) }
        async let heart = latestHeartRate()
        async let sleep = sleepHours()
        async let steps = stepCountToday()
        return await DayHealth(heartRate: heart, sleepHours: sleep, steps: steps)
    }

    private static func record(from workout: HKWorkout, sport: SportKind, route: [GeoPoint]) -> WorkoutRecord {
        // Prefer statistics. Some imported workouts leave statistics(for:) nil and only
        // fill the older totals, which would otherwise be stored as 0.
        // Heart rate has no workout-level total, so it stays on statistics.
        let distance = sum(workout, identifier: .distanceWalkingRunning, unit: .meter())
            ?? workout.totalDistance?.doubleValue(for: .meter())
            ?? 0
        let energy = sum(workout, identifier: .activeEnergyBurned, unit: .kilocalorie())
            ?? workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
            ?? 0
        let heart = average(workout, identifier: .heartRate, unit: HKUnit.count().unitDivided(by: .minute())) ?? 0
        var climb = 0.0
        if let quantity = workout.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity {
            climb = quantity.doubleValue(for: .meter())
        }
        return WorkoutRecord(
            id: UUID(),
            sport: sport,
            start: workout.startDate,
            end: workout.endDate,
            distanceMeters: distance,
            energyKilocalories: energy,
            averageHeartRate: heart,
            averageCadence: 0,
            elevationGainMeters: climb,
            route: route,
            splits: [],
            heartRate: [],
            cadenceSeries: [],
            paceSeries: [],
            stride: [],
            elevation: [],
            groundContact: [],
            power: [],
            origin: .apple,
            healthKitUUID: workout.uuid.uuidString
        )
    }

    private static func sum(_ workout: HKWorkout, identifier: HKQuantityTypeIdentifier, unit: HKUnit) -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        return workout.statistics(for: type)?.sumQuantity()?.doubleValue(for: unit)
    }

    private static func average(_ workout: HKWorkout, identifier: HKQuantityTypeIdentifier, unit: HKUnit) -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        return workout.statistics(for: type)?.averageQuantity()?.doubleValue(for: unit)
    }

    private static func routePoints(for workout: HKWorkout) async -> [GeoPoint] {
        await withCheckedContinuation { continuation in
            let once = ResumeOnce()
            let bag = PointBag()
            let predicate = HKQuery.predicateForObjects(from: workout)
            let query = HKSampleQuery(
                sampleType: HKSeriesType.workoutRoute(),
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, _ in
                guard let route = samples?.first as? HKWorkoutRoute else {
                    once.resume { continuation.resume(returning: []) }
                    return
                }
                let routeQuery = HKWorkoutRouteQuery(route: route) { _, locations, done, error in
                    if let locations {
                        bag.append(locations)
                    }
                    if done || error != nil {
                        once.resume { continuation.resume(returning: bag.points) }
                    }
                }
                store.execute(routeQuery)
            }
            store.execute(query)
        }
    }

    private static func latestHeartRate() async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return nil }
        let unit = HKUnit.count().unitDivided(by: .minute())
        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let sample = samples?.first as? HKQuantitySample
                continuation.resume(returning: sample?.quantity.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private static func stepCountToday() async -> Int? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return nil }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                let steps = stats?.sumQuantity()?.doubleValue(for: .count())
                continuation.resume(returning: steps.map { Int($0.rounded()) })
            }
            store.execute(query)
        }
    }

    private static func sleepHours() async -> Double? {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let start = Date().addingTimeInterval(-36 * 60 * 60)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let asleep: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                    1 // older asleep samples
                ]
                let seconds = (samples as? [HKCategorySample] ?? []).reduce(0.0) { partial, sample in
                    guard asleep.contains(sample.value) else { return partial }
                    return partial + sample.endDate.timeIntervalSince(sample.startDate)
                }
                continuation.resume(returning: seconds > 0 ? seconds / 3600 : nil)
            }
            store.execute(query)
        }
    }

    private static var shareTypes: Set<HKSampleType> {
        // save(route:) writes an HKWorkoutRoute, so share permission has to include the series type.
        var types: Set<HKSampleType> = [HKObjectType.workoutType(), HKSeriesType.workoutRoute()]
        for identifier in [HKQuantityTypeIdentifier.heartRate, .activeEnergyBurned, .distanceWalkingRunning] {
            if let type = HKQuantityType.quantityType(forIdentifier: identifier) {
                types.insert(type)
            }
        }
        return types
    }

    private static var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType(), HKSeriesType.workoutRoute()]
        let quantities: [HKQuantityTypeIdentifier] = [
            .heartRate, .activeEnergyBurned, .distanceWalkingRunning, .stepCount,
            .runningPower, .runningStrideLength, .runningGroundContactTime, .flightsClimbed
        ]
        for identifier in quantities {
            if let type = HKQuantityType.quantityType(forIdentifier: identifier) {
                types.insert(type)
            }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        return types
    }
}

extension SportKind {
    var hkActivity: HKWorkoutActivityType {
        switch self {
        case .running: return .running
        case .hiking: return .hiking
        }
    }

    static func from(_ type: HKWorkoutActivityType) -> SportKind? {
        switch type {
        case .running: return .running
        case .hiking: return .hiking
        default: return nil
        }
    }
}

final class AppleWorkoutRecorder: NSObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    struct Reading {
        var heartRate: Double?
        var distance: Double?
        var energy: Double?
        var power: Double?
        var stride: Double?
        var groundContactMilliseconds: Double?
    }

    var onReading: ((Reading) -> Void)?
    var onFailure: ((String) -> Void)?

    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var collecting = false

    func start(sport: SportKind) async throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = sport.hkActivity
        configuration.locationType = .outdoor
        let session = try HKWorkoutSession(healthStore: AppleHealth.store, configuration: configuration)
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: AppleHealth.store, workoutConfiguration: configuration)
        session.delegate = self
        builder.delegate = self
        self.session = session
        self.builder = builder
        let start = Date()
        session.startActivity(with: start)
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                builder.beginCollection(withStart: start) { success, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if success {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: RecorderError.failed)
                    }
                }
            }
            collecting = true
        } catch {
            discard()
            throw error
        }
    }

    func pause() {
        session?.pause()
    }

    func resume() {
        session?.resume()
    }

    var isSessionOpen: Bool { session != nil }

    /// Ends the session without `finishWorkout`, so Health does not keep a workout or route.
    func discard() {
        guard let session, let builder else { return }
        let wasCollecting = collecting
        collecting = false
        self.session = nil
        self.builder = nil
        if wasCollecting {
            builder.discardWorkout()
        }
        session.end()
    }

    struct FinishOutcome {
        var healthID: String?
        var routeError: String?
    }

    func finish(route: [GeoPoint]) async -> FinishOutcome {
        guard let session, let builder else { return FinishOutcome(healthID: nil, routeError: nil) }
        collecting = false
        session.end()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            builder.endCollection(withEnd: Date()) { _, _ in
                continuation.resume()
            }
        }
        let workout: HKWorkout? = await withCheckedContinuation { continuation in
            builder.finishWorkout { workout, _ in
                continuation.resume(returning: workout)
            }
        }
        self.session = nil
        self.builder = nil
        var routeError: String?
        if let workout, route.count >= 2 {
            do {
                try await save(route: route, workout: workout)
            } catch {
                routeError = error.localizedDescription
            }
        }
        return FinishOutcome(healthID: workout?.uuid.uuidString, routeError: routeError)
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {}

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        onFailure?(error.localizedDescription)
    }

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        onReading?(reading(from: workoutBuilder))
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    private func reading(from builder: HKLiveWorkoutBuilder) -> Reading {
        Reading(
            heartRate: recent(builder, .heartRate, HKUnit.count().unitDivided(by: .minute())),
            distance: sum(builder, .distanceWalkingRunning, .meter()),
            energy: sum(builder, .activeEnergyBurned, .kilocalorie()),
            power: recent(builder, .runningPower, .watt()),
            stride: recent(builder, .runningStrideLength, .meter()),
            groundContactMilliseconds: recent(builder, .runningGroundContactTime, .second()).map { $0 * 1000 }
        )
    }

    private func recent(_ builder: HKLiveWorkoutBuilder, _ identifier: HKQuantityTypeIdentifier, _ unit: HKUnit) -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        return builder.statistics(for: type)?.mostRecentQuantity()?.doubleValue(for: unit)
    }

    private func sum(_ builder: HKLiveWorkoutBuilder, _ identifier: HKQuantityTypeIdentifier, _ unit: HKUnit) -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        return builder.statistics(for: type)?.sumQuantity()?.doubleValue(for: unit)
    }

    private func save(route: [GeoPoint], workout: HKWorkout) async throws {
        let locations = route.map { point in
            CLLocation(
                coordinate: point.coordinate,
                altitude: point.altitude,
                horizontalAccuracy: 8,
                verticalAccuracy: 8,
                timestamp: point.timestamp ?? Date()
            )
        }
        let builder = HKWorkoutRouteBuilder(healthStore: AppleHealth.store, device: nil)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.insertRouteData(locations) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard success else {
                    continuation.resume(throwing: RecorderError.failed)
                    return
                }
                builder.finishRoute(with: workout, metadata: nil) { saved, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if saved == nil {
                        continuation.resume(throwing: RecorderError.failed)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }
}

private final class PointBag: @unchecked Sendable {
    private(set) var points: [GeoPoint] = []
    private let lock = NSLock()

    func append(_ locations: [CLLocation]) {
        lock.lock()
        points.append(contentsOf: locations.map { location in
            GeoPoint(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                altitude: location.altitude,
                timestamp: location.timestamp
            )
        })
        lock.unlock()
    }
}

private final class ResumeOnce: @unchecked Sendable {
    private var fired = false
    private let lock = NSLock()

    func resume(_ body: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !fired else { return }
        fired = true
        body()
    }
}

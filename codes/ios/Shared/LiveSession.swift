import Combine
import CoreLocation
import CoreMotion
import Foundation

@MainActor
final class LiveSession: ObservableObject {
    enum Phase {
        case idle
        case running
        case finished
    }

    let sport: SportKind
    let plannedRoute: [GeoPoint]
    let memberProfiles: [TeammateProfile]

    @Published var phase: Phase = .idle
    @Published var paused = false
    @Published var simulating = false
    @Published var statusText = ""
    @Published var elapsed: TimeInterval = 0
    @Published var distanceMeters: Double = 0
    @Published var paceSecPerKm: Double = 0
    @Published var heartRate: Double = 0
    @Published var cadence: Double = 0
    @Published var energyKilocalories: Double = 0
    @Published var elevationGainMeters: Double = 0
    /// Downsampled for the map. The saved record and the HealthKit route use `recordedRoute`.
    @Published var route: [GeoPoint] = []
    @Published var splits: [KilometerSplit] = []
    @Published var teammates: [TeammateLive] = []
    private(set) var routeSaveWarning: String?

    private let recorder = AppleWorkoutRecorder()
    private let sync: TeammateSync = LocalTeammateSimulator()
    private let pedometer = CMPedometer()
    private let location = CLLocationManager()
    private let locationProxy = LocationProxy()
    private var timer: Timer?
    private var startedAt = Date()
    private var runningSince: Date?
    private var banked: TimeInterval = 0
    private var gpsDistance = 0.0
    private var healthDistance = 0.0
    private var lastLocation: CLLocation?
    private var lastAltitude: Double?
    /// First fix after resume is the cached pre-pause coordinate. Do not anchor on it.
    private var ignoreNextLocation = false
    /// Samples stamped before this were taken during the pause.
    private var resumeAnchorDate = Date.distantPast
    private var splitStartDistance = 0.0
    private var splitStartElapsed: TimeInterval = 0
    private var splitHearts: [Double] = []
    private var splitCadences: [Double] = []
    private var heartSeries: [SeriesPoint] = []
    private var cadenceSeries: [SeriesPoint] = []
    private var paceSeries: [SeriesPoint] = []
    private var strideSeries: [SeriesPoint] = []
    private var elevationSeries: [SeriesPoint] = []
    private var contactSeries: [SeriesPoint] = []
    private var powerSeries: [SeriesPoint] = []
    private var stepCount = 0.0
    private var latestPower = 0.0
    private var latestStride = 0.0
    private var latestContact = 0.0
    private var simHeading = 0.4
    private var simPoint = SampleLibrary.plannedRoutes(around: MapOrigin.fallback)[0].points.first ?? MapOrigin.fallback
    private var sampleTick = 0
    private var usedApple = false
    private var leavingApple = false
    private var teammatesStarted = false
    /// Every accepted point. Display uses a downsample of this.
    private var recordedRoute: [GeoPoint] = []

    init(sport: SportKind, plannedRoute: [GeoPoint], teammates: [TeammateProfile]) {
        self.sport = sport
        self.plannedRoute = plannedRoute
        self.memberProfiles = teammates
        simPoint = MapOrigin.fallback
    }

    var currentSplit: KilometerSplit {
        let deltaDistance = max(0, distanceMeters - splitStartDistance)
        let deltaTime = max(0, elapsed - splitStartElapsed)
        let pace = deltaDistance > 15 ? deltaTime / (deltaDistance / 1000) : 0
        return KilometerSplit(
            index: splits.count + 1,
            paceSecPerKm: pace,
            cadence: mean(splitCadences),
            heartRate: mean(splitHearts),
            partial: true
        )
    }

    func start() async {
        guard phase == .idle else { return }
        phase = .running
        startedAt = Date()
        runningSince = Date()
        wireCallbacks()
        startTimer()
        // Location stays off until HealthKit either starts or we choose simulation.
        // Points collected before that choice were being kept, then simulation jumped
        // to the fallback origin and appended a fake track onto them.
        if AppleHealth.available {
            do {
                try await AppleHealth.authorize()
                guard phase == .running else { return }
                try await recorder.start(sport: sport)
                guard phase == .running else {
                    // stop() already kept a record with no HealthKit id. Do not save this session.
                    recorder.discard()
                    return
                }
                usedApple = true
                simulating = false
                statusText = ""
                startPedometer()
                startLocation()
            } catch {
                guard phase == .running else { return }
                beginSimulation("健康数据没有启动，已改用本地模拟")
            }
        } else {
            beginSimulation("这台设备没有健康数据，已改用本地模拟")
        }
        guard phase == .running else { return }
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self, self.phase == .running, !self.teammatesStarted else { return }
            if let location = self.lastLocation {
                self.startTeammates(at: GeoPoint(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    altitude: location.altitude,
                    timestamp: location.timestamp
                ))
            } else {
                self.startTeammates(at: MapOrigin.fallback)
            }
        }
    }

    func pause() {
        guard phase == .running, !paused else { return }
        banked = elapsed
        runningSince = nil
        paused = true
        location.stopUpdatingLocation()
        lastLocation = nil
        lastAltitude = nil
        if usedApple { recorder.pause() }
        pedometer.stopUpdates()
    }

    func resume() {
        guard phase == .running, paused else { return }
        runningSince = Date()
        paused = false
        if usedApple { recorder.resume() }
        guard !simulating else { return }
        startPedometer()
        ignoreNextLocation = true
        resumeAnchorDate = Date()
        location.startUpdatingLocation()
    }

    func stop() async -> WorkoutRecord {
        if phase == .running {
            banked = elapsed
            runningSince = nil
            elapsed = banked
        }
        phase = .finished
        timer?.invalidate()
        pedometer.stopUpdates()
        location.stopUpdatingLocation()
        let leftover = distanceMeters - splitStartDistance
        if leftover > 30 {
            closeSplit(distance: leftover, partial: true)
        }
        leavingApple = true
        var healthID: String?
        if usedApple {
            let outcome = await recorder.finish(route: recordedRoute)
            healthID = outcome.healthID
            if let routeError = outcome.routeError {
                routeSaveWarning = "路线没有写入健康：\(routeError)"
                statusText = routeSaveWarning ?? ""
            }
        }
        usedApple = false
        sync.stop()
        return makeRecord(healthID: healthID)
    }

    /// Drops the Apple session without saving it, then records only simulated points.
    private func beginSimulation(_ reason: String) {
        guard phase == .running, !simulating, !leavingApple else { return }
        leavingApple = true
        usedApple = false
        location.stopUpdatingLocation()
        pedometer.stopUpdates()
        if recorder.isSessionOpen {
            recorder.discard()
        }
        guard phase == .running else { return }
        statusText = reason
        resetTrack()
        simulating = true
        leavingApple = false
        simPoint = MapOrigin.fallback
        startTeammates(at: MapOrigin.fallback)
    }

    private func startTeammates(at origin: GeoPoint) {
        guard !teammatesStarted, !memberProfiles.isEmpty else { return }
        teammatesStarted = true
        sync.onChange = { [weak self] lives in
            Task { @MainActor in
                self?.teammates = lives
            }
        }
        sync.start(
            context: TeamSessionContext(teamID: UUID(), sport: sport, members: memberProfiles),
            origin: origin
        )
    }

    private func wireCallbacks() {
        recorder.onReading = { [weak self] reading in
            Task { @MainActor in
                self?.apply(reading)
            }
        }
        recorder.onFailure = { [weak self] message in
            Task { @MainActor in
                guard let self, self.phase == .running, !self.simulating, !self.leavingApple else { return }
                self.beginSimulation("锻炼中断（\(message)），已改用本地模拟")
            }
        }
        locationProxy.onLocation = { [weak self] location in
            Task { @MainActor in
                self?.apply(location)
            }
        }
    }

    private func startTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func startPedometer() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        pedometer.startUpdates(from: Date()) { [weak self] data, _ in
            guard let data else { return }
            let cadence = (data.currentCadence?.doubleValue ?? 0) * 60
            let steps = data.numberOfSteps.doubleValue
            Task { @MainActor in
                guard let self, !self.simulating, !self.paused, !self.leavingApple else { return }
                if cadence > 0 {
                    self.cadence = cadence
                    self.splitCadences.append(cadence)
                }
                self.stepCount = steps
            }
        }
    }

    private func startLocation() {
        location.delegate = locationProxy
        location.activityType = .fitness
        location.desiredAccuracy = kCLLocationAccuracyBest
        location.requestWhenInUseAuthorization()
        location.startUpdatingLocation()
    }

    private func tick() {
        guard phase == .running, !paused, !leavingApple else { return }
        if let runningSince {
            elapsed = banked + Date().timeIntervalSince(runningSince)
        }
        if simulating {
            advanceSimulation()
        }
        refreshDistance()
        noteSplitProgress()
        sampleTick += 1
        if sampleTick % 5 == 0 {
            captureSample()
        }
        if let last = route.last {
            sync.publish(AthleteSnapshot(
                latitude: last.latitude,
                longitude: last.longitude,
                paceSecPerKm: paceSecPerKm,
                heartRate: heartRate,
                date: Date()
            ))
        }
    }

    private func advanceSimulation() {
        let speed = sport == .running ? Double.random(in: 2.7...3.15) : Double.random(in: 1.15...1.45)
        simHeading += Double.random(in: -0.25...0.25)
        let north = cos(simHeading) * speed
        let east = sin(simHeading) * speed
        simPoint = simPoint.moved(northMeters: north, eastMeters: east)
        simPoint.altitude = 18 + 6 * sin(elapsed / 40)
        simPoint.timestamp = Date()
        gpsDistance += speed
        appendPoint(simPoint)
        paceSecPerKm = 1000 / speed
        heartRate = (sport == .running ? 156 : 118) + sin(elapsed / 12) * 6
        cadence = sport == .running ? 174 + sin(elapsed / 9) * 4 : 110 + sin(elapsed / 10) * 3
        // HealthKit is not feeding energy here. Rough display estimate only: 65 kcal/km running, 50 hiking.
        energyKilocalories = (gpsDistance / 1000) * (sport == .running ? 65 : 50)
        noteAltitude(simPoint.altitude)
        splitHearts.append(heartRate)
        splitCadences.append(cadence)
    }

    private func apply(_ reading: AppleWorkoutRecorder.Reading) {
        guard phase == .running, !paused, !simulating, !leavingApple else { return }
        if let heart = reading.heartRate, heart > 0 {
            heartRate = heart
            splitHearts.append(heart)
        }
        if let distance = reading.distance, distance > 0 {
            healthDistance = distance
        }
        if let energy = reading.energy, energy > 0 {
            energyKilocalories = energy
        }
        if let power = reading.power, power > 0 { latestPower = power }
        if let stride = reading.stride, stride > 0 { latestStride = stride }
        if let contact = reading.groundContactMilliseconds, contact > 0 { latestContact = contact }
        refreshDistance()
    }

    private func apply(_ location: CLLocation) {
        guard phase == .running, !paused, !simulating, !leavingApple else { return }
        if ignoreNextLocation || location.timestamp < resumeAnchorDate {
            ignoreNextLocation = false
            return
        }
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy < 40 else { return }
        if let lastLocation {
            let delta = location.distance(from: lastLocation)
            if delta > 0.8, delta < 40 {
                gpsDistance += delta
            }
        }
        lastLocation = location
        startTeammates(at: GeoPoint(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            timestamp: location.timestamp
        ))
        if location.speed > 0.4 {
            paceSecPerKm = 1000 / location.speed
        }
        let point = GeoPoint(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            timestamp: location.timestamp
        )
        appendPoint(point)
        noteAltitude(location.altitude)
        refreshDistance()
    }

    private func appendPoint(_ point: GeoPoint) {
        recordedRoute.append(point)
        route = Self.displayRoute(recordedRoute)
    }

    /// Map display only. `recordedRoute` stays complete for the saved workout and HealthKit.
    private static func displayRoute(_ points: [GeoPoint]) -> [GeoPoint] {
        let limit = 600
        guard points.count > limit else { return points }
        let lastIndex = points.count - 1
        return (0..<limit).map { slot in
            let index = Int((Double(slot) * Double(lastIndex) / Double(limit - 1)).rounded())
            return points[index]
        }
    }

    private func resetTrack() {
        recordedRoute = []
        route = []
        gpsDistance = 0
        healthDistance = 0
        distanceMeters = 0
        paceSecPerKm = 0
        heartRate = 0
        cadence = 0
        energyKilocalories = 0
        elevationGainMeters = 0
        lastLocation = nil
        lastAltitude = nil
        ignoreNextLocation = false
        resumeAnchorDate = .distantPast
        splits = []
        splitStartDistance = 0
        splitStartElapsed = 0
        splitHearts = []
        splitCadences = []
        heartSeries = []
        cadenceSeries = []
        paceSeries = []
        strideSeries = []
        elevationSeries = []
        contactSeries = []
        powerSeries = []
        stepCount = 0
        latestPower = 0
        latestStride = 0
        latestContact = 0
        sampleTick = 0
        startedAt = Date()
        runningSince = Date()
        banked = 0
        elapsed = 0
    }

    private func refreshDistance() {
        distanceMeters = max(gpsDistance, healthDistance)
        if paceSecPerKm == 0, elapsed > 20, distanceMeters > 30 {
            paceSecPerKm = elapsed / (distanceMeters / 1000)
        }
    }

    private func noteAltitude(_ altitude: Double) {
        if let lastAltitude, altitude > lastAltitude {
            elevationGainMeters += altitude - lastAltitude
        }
        lastAltitude = altitude
    }

    private func noteSplitProgress() {
        while distanceMeters - splitStartDistance >= 1000 {
            closeSplit(distance: 1000, partial: false)
            splitStartDistance += 1000
            splitStartElapsed = elapsed
            splitHearts = []
            splitCadences = []
        }
    }

    private func closeSplit(distance: Double, partial: Bool) {
        let deltaTime = max(1, elapsed - splitStartElapsed)
        let pace = deltaTime / (distance / 1000)
        splits.append(KilometerSplit(
            index: splits.count + 1,
            paceSecPerKm: pace,
            cadence: mean(splitCadences),
            heartRate: mean(splitHearts),
            partial: partial
        ))
    }

    private func captureSample() {
        let second = elapsed
        if heartRate > 0 { heartSeries.append(SeriesPoint(second: second, value: heartRate)) }
        if cadence > 0 { cadenceSeries.append(SeriesPoint(second: second, value: cadence)) }
        if paceSecPerKm > 0 { paceSeries.append(SeriesPoint(second: second, value: paceSecPerKm)) }
        elevationSeries.append(SeriesPoint(second: second, value: lastAltitude ?? route.last?.altitude ?? 0))
        if simulating {
            let stride = sport == .running ? 1.12 + sin(elapsed / 15) * 0.06 : 0.76 + sin(elapsed / 18) * 0.04
            let contact = sport == .running ? 230 + sin(elapsed / 11) * 12 : 284 + sin(elapsed / 13) * 8
            let watts = sport == .running ? 240 + sin(elapsed / 8) * 20 : 148 + sin(elapsed / 9) * 12
            strideSeries.append(SeriesPoint(second: second, value: stride))
            contactSeries.append(SeriesPoint(second: second, value: contact))
            powerSeries.append(SeriesPoint(second: second, value: watts))
        } else {
            if latestStride > 0 {
                strideSeries.append(SeriesPoint(second: second, value: latestStride))
            } else if cadence > 30, paceSecPerKm > 0 {
                let speed = 1000 / paceSecPerKm
                strideSeries.append(SeriesPoint(second: second, value: speed / (cadence / 60)))
            }
            if latestContact > 0 {
                contactSeries.append(SeriesPoint(second: second, value: latestContact))
            }
            if latestPower > 0 {
                powerSeries.append(SeriesPoint(second: second, value: latestPower))
            }
        }
    }

    private func makeRecord(healthID: String?) -> WorkoutRecord {
        let end = startedAt.addingTimeInterval(max(elapsed, 1))
        let hearts = heartSeries.map(\.value)
        let cadences = cadenceSeries.map(\.value)
        return WorkoutRecord(
            id: UUID(),
            sport: sport,
            start: startedAt,
            end: end,
            distanceMeters: distanceMeters,
            energyKilocalories: energyKilocalories,
            averageHeartRate: mean(hearts),
            averageCadence: mean(cadences),
            elevationGainMeters: elevationGainMeters,
            route: recordedRoute,
            splits: splits,
            heartRate: heartSeries,
            cadenceSeries: cadenceSeries,
            paceSeries: paceSeries,
            stride: strideSeries,
            elevation: elevationSeries,
            groundContact: contactSeries,
            power: powerSeries,
            origin: simulating ? .simulated : .apple,
            healthKitUUID: healthID
        )
    }

    private func mean(_ values: [Double]) -> Double {
        let usable = values.filter { $0 > 0 }
        guard !usable.isEmpty else { return 0 }
        return usable.reduce(0, +) / Double(usable.count)
    }
}

enum MapOrigin {
    static let fallback = GeoPoint(latitude: 31.240, longitude: 121.490, altitude: 12, timestamp: nil)
}

final class LocationProxy: NSObject, CLLocationManagerDelegate {
    var onLocation: ((CLLocation) -> Void)?

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        onLocation?(location)
    }
}

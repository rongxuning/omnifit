import Foundation

enum SampleLibrary {
    static let teammates: [TeammateProfile] = [
        TeammateProfile(id: "aning", name: "阿宁"),
        TeammateProfile(id: "xiaolin", name: "小林"),
        TeammateProfile(id: "zhouzhou", name: "周舟")
    ]

    static func presetRunningRoute() -> SavedRoute {
        SavedRoute(
            id: SavedRoute.presetRunningID,
            name: "湖滨环线",
            points: loop(MapOrigin.fallback, radii: [0, 180, 420, 460, 220], closed: true),
            kind: .presetRunning
        )
    }

    static func plannedRoutes(around origin: GeoPoint) -> [PlannedRoute] {
        [
            .free,
            PlannedRoute(id: "lake", name: "湖滨环线", points: loop(origin, radii: [0, 180, 420, 460, 220], closed: true)),
            PlannedRoute(id: "river", name: "滨河步道", points: loop(origin, radii: [0, 140, 300, 520, 700], closed: false))
        ]
    }

    static func workouts() -> [WorkoutRecord] {
        [
            make(
                id: "10000000-0000-0000-0000-000000000001",
                sport: .running,
                month: 10, day: 14, hour: 7, minute: 12,
                minutes: 38,
                kilometers: 6.42,
                energy: 428,
                heart: 152,
                cadence: 172,
                climb: 48,
                originLat: 31.241,
                originLon: 121.491,
                paces: [362, 341, 355, 338, 351, 364, 402]
            ),
            make(
                id: "10000000-0000-0000-0000-000000000002",
                sport: .hiking,
                month: 10, day: 12, hour: 9, minute: 30,
                minutes: 166,
                kilometers: 12.80,
                energy: 786,
                heart: 118,
                cadence: 112,
                climb: 420,
                originLat: 31.228,
                originLon: 121.478,
                paces: [760, 742, 780, 755, 770, 748, 790, 734, 768, 752, 810, 744, 690]
            ),
            make(
                id: "10000000-0000-0000-0000-000000000003",
                sport: .running,
                month: 10, day: 9, hour: 18, minute: 5,
                minutes: 54,
                kilometers: 10.02,
                energy: 612,
                heart: 158,
                cadence: 176,
                climb: 86,
                originLat: 31.252,
                originLon: 121.505,
                paces: [330, 318, 324, 312, 328, 336, 320, 314, 340, 308, 290]
            ),
            make(
                id: "10000000-0000-0000-0000-000000000004",
                sport: .hiking,
                month: 10, day: 5, hour: 8, minute: 40,
                minutes: 112,
                kilometers: 8.40,
                energy: 540,
                heart: 112,
                cadence: 108,
                climb: 260,
                originLat: 31.236,
                originLon: 121.470,
                paces: [800, 780, 820, 760, 790, 810, 770, 840, 700]
            )
        ]
    }

    static func posts() -> [SocialPost] {
        let routes = workouts()
        return [
            SocialPost(
                id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
                author: "阿宁",
                isMine: false,
                createdAt: date(10, 15, 7, 40),
                sport: .running,
                distanceMeters: 6_400,
                duration: 38 * 60,
                paceSecPerKm: 356,
                energyKilocalories: 420,
                text: "早起沿湖跑完，风很轻。",
                imageFilename: nil,
                route: routes[0].route
            ),
            SocialPost(
                id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!,
                author: "小林",
                isMine: false,
                createdAt: date(10, 13, 16, 5),
                sport: .hiking,
                distanceMeters: 9_200,
                duration: 150 * 60,
                paceSecPerKm: 978,
                energyKilocalories: 610,
                text: "山路有点泥，心率还算稳。",
                imageFilename: nil,
                route: routes[1].route
            ),
            SocialPost(
                id: UUID(uuidString: "20000000-0000-0000-0000-000000000003")!,
                author: "周舟",
                isMine: false,
                createdAt: date(10, 11, 19, 12),
                sport: .running,
                distanceMeters: 8_000,
                duration: 47 * 60,
                paceSecPerKm: 352,
                energyKilocalories: 540,
                text: "配速压在六分以内，后两公里有点顶。",
                imageFilename: nil,
                route: routes[2].route
            )
        ]
    }

    private static func make(
        id: String,
        sport: SportKind,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        minutes: Double,
        kilometers: Double,
        energy: Double,
        heart: Double,
        cadence: Double,
        climb: Double,
        originLat: Double,
        originLon: Double,
        paces: [Double]
    ) -> WorkoutRecord {
        let start = date(month, day, hour, minute)
        let duration = minutes * 60
        let end = start.addingTimeInterval(duration)
        let distance = kilometers * 1000
        let route = routeLine(start: start, meters: distance, lat: originLat, lon: originLon, climb: climb)
        let fullCount = Int(kilometers)
        let splits: [KilometerSplit] = paces.enumerated().map { index, pace in
            KilometerSplit(
                index: index + 1,
                paceSecPerKm: pace,
                cadence: cadence + Double((index % 5) - 2),
                heartRate: heart + Double((index % 4) - 1),
                partial: index >= fullCount
            )
        }
        return WorkoutRecord(
            id: UUID(uuidString: id)!,
            sport: sport,
            start: start,
            end: end,
            distanceMeters: distance,
            energyKilocalories: energy,
            averageHeartRate: heart,
            averageCadence: cadence,
            elevationGainMeters: climb,
            route: route,
            splits: splits,
            heartRate: wave(duration, base: heart, amp: 8, floor: 70),
            cadenceSeries: wave(duration, base: cadence, amp: 6, floor: 60),
            paceSeries: wave(duration, base: duration / kilometers, amp: 18, floor: 180),
            stride: wave(duration, base: sport == .running ? 1.15 : 0.78, amp: 0.08, floor: 0.4),
            elevation: elevationSeries(duration, route: route),
            groundContact: wave(duration, base: sport == .running ? 228 : 286, amp: 14, floor: 160),
            power: wave(duration, base: sport == .running ? 246 : 150, amp: 24, floor: 40),
            origin: .sample,
            healthKitUUID: nil
        )
    }

    private static func date(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var parts = DateComponents()
        parts.calendar = Calendar(identifier: .gregorian)
        parts.timeZone = TimeZone(identifier: "Asia/Shanghai")
        parts.year = 2026
        parts.month = month
        parts.day = day
        parts.hour = hour
        parts.minute = minute
        return parts.date ?? Date()
    }

    private static func wave(_ duration: TimeInterval, base: Double, amp: Double, floor: Double) -> [SeriesPoint] {
        var points: [SeriesPoint] = []
        var second = 0.0
        var index = 0
        while second <= duration {
            let value = max(floor, base + amp * sin(Double(index) * 0.65) + amp * 0.35 * cos(Double(index) * 0.21))
            points.append(SeriesPoint(second: second, value: value))
            second += 20
            index += 1
        }
        return points
    }

    private static func elevationSeries(_ duration: TimeInterval, route: [GeoPoint]) -> [SeriesPoint] {
        guard !route.isEmpty else { return [] }
        return route.enumerated().map { index, point in
            let second = duration * Double(index) / Double(max(route.count - 1, 1))
            return SeriesPoint(second: second, value: point.altitude)
        }
    }

    private static func routeLine(start: Date, meters: Double, lat: Double, lon: Double, climb: Double) -> [GeoPoint] {
        var points: [GeoPoint] = []
        var latitude = lat
        var longitude = lon
        var left = meters
        var index = 0
        let step = 50.0
        while left > 0 {
            let heading = Double(index) * 0.42
            let piece = min(step, left)
            latitude += cos(heading) * piece / 111_320
            longitude += sin(heading) * piece / (111_320 * cos(lat * .pi / 180))
            let climbed = climb * (1 - left / max(meters, 1))
            let time = start.addingTimeInterval(Double(index) * 15)
            points.append(GeoPoint(latitude: latitude, longitude: longitude, altitude: 12 + climbed, timestamp: time))
            left -= piece
            index += 1
        }
        return points
    }

    private static func loop(_ origin: GeoPoint, radii: [Double], closed: Bool) -> [GeoPoint] {
        var points: [GeoPoint] = []
        for (index, radius) in radii.enumerated() {
            let angle = Double(index) / Double(max(radii.count - 1, 1)) * (closed ? 2 * .pi : .pi * 0.8)
            points.append(origin.moved(northMeters: cos(angle) * radius, eastMeters: sin(angle) * radius * 1.4))
        }
        if closed, let first = points.first {
            points.append(first)
        }
        return points
    }
}

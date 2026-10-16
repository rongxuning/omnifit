import Foundation

/// Transport for live teammate location, pace, and heart rate.
///
/// `publish` is the outgoing hook a real transport would send off the device.
/// This repository does not include a server. `LocalTeammateSimulator` is the
/// only implementation: it moves a few sample people on a timer and does not
/// open a network connection. `publish` is recorded locally and then ignored.
protocol TeammateSync: AnyObject {
    var onChange: (([TeammateLive]) -> Void)? { get set }
    func start(context: TeamSessionContext, origin: GeoPoint)
    func publish(_ snapshot: AthleteSnapshot)
    func stop()
}

/// Local stand-in so the team screen works on a device with no backend.
final class LocalTeammateSimulator: TeammateSync {
    var onChange: (([TeammateLive]) -> Void)?

    private var timer: Timer?
    private var people: [MovingPerson] = []
    private var origin = GeoPoint(latitude: 31.24, longitude: 121.49, altitude: 0, timestamp: nil)
    private(set) var lastPublished: AthleteSnapshot?

    func start(context: TeamSessionContext, origin: GeoPoint) {
        stop()
        self.origin = origin
        people = context.members.enumerated().map { index, member in
            MovingPerson(
                id: member.id,
                name: member.name,
                north: Double(index + 1) * 80,
                east: Double(index - 1) * 60,
                heading: Double(index) * 1.3,
                pace: context.sport == .running ? 340 + Double(index) * 12 : 720 + Double(index) * 20,
                heart: context.sport == .running ? 148 + Double(index) * 6 : 112 + Double(index) * 4
            )
        }
        emit()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func publish(_ snapshot: AthleteSnapshot) {
        lastPublished = snapshot
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        people = []
        onChange?([])
    }

    private func tick() {
        for index in people.indices {
            people[index].heading += Double.random(in: -0.35...0.35)
            let speed = 1000 / max(people[index].pace, 120)
            people[index].north += cos(people[index].heading) * speed
            people[index].east += sin(people[index].heading) * speed
            people[index].pace += Double.random(in: -4...4)
            people[index].heart += Double.random(in: -2...2)
            people[index].pace = min(max(people[index].pace, 250), 900)
            people[index].heart = min(max(people[index].heart, 90), 185)
        }
        emit()
    }

    private func emit() {
        let lives = people.map { person in
            let point = origin.moved(northMeters: person.north, eastMeters: person.east)
            return TeammateLive(
                id: person.id,
                name: person.name,
                latitude: point.latitude,
                longitude: point.longitude,
                paceSecPerKm: person.pace,
                heartRate: person.heart
            )
        }
        onChange?(lives)
    }
}

private struct MovingPerson {
    var id: String
    var name: String
    var north: Double
    var east: Double
    var heading: Double
    var pace: Double
    var heart: Double
}

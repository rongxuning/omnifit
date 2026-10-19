import Combine
import Foundation

@MainActor
final class WatchAppState: ObservableObject {
    @Published private(set) var database: Database

    private let filename = "watch.json"

    init() {
        if let loaded = AppFiles.load(filename), loaded.seeded {
            database = loaded
        } else {
            var fresh = Database()
            fresh.workouts = SampleLibrary.workouts()
            fresh.posts = SampleLibrary.posts()
            fresh.seeded = true
            database = fresh
            AppFiles.save(fresh, name: filename)
        }
    }

    var workouts: [WorkoutRecord] {
        database.workouts
            .filter { $0.sport == .hiking || $0.sport == .running }
            .sorted { $0.start > $1.start }
    }

    var posts: [SocialPost] {
        database.posts.sorted { $0.createdAt > $1.createdAt }
    }

    var members: [TeammateProfile] {
        SampleLibrary.teammates.filter { database.selectedTeammateIDs.contains($0.id) }
    }

    func stats(for window: StatsWindow) -> TrainingStats {
        RecordStats.make(workouts: workouts, window: window)
    }

    func estimate() -> TrainingEstimateSummary {
        TrainingEstimate.summarize(workouts: workouts)
    }

    func toggleTeammate(_ id: String) {
        mutate { database in
            if let index = database.selectedTeammateIDs.firstIndex(of: id) {
                database.selectedTeammateIDs.remove(at: index)
            } else {
                database.selectedTeammateIDs.append(id)
            }
        }
    }

    func add(_ record: WorkoutRecord) {
        mutate { database in
            database.workouts.removeAll { $0.id == record.id }
            if let healthID = record.healthKitUUID {
                database.workouts.removeAll { $0.healthKitUUID == healthID }
            }
            database.workouts.append(record)
            database.workouts.sort { $0.start > $1.start }
        }
    }

    func importFromApple() async {
        guard AppleHealth.available else { return }
        do {
            try await AppleHealth.authorize()
            let imported = try await AppleActivitySource().importRunsAndHikes()
            mutate { database in
                for record in imported {
                    guard let healthID = record.healthKitUUID else { continue }
                    if database.workouts.contains(where: { $0.healthKitUUID == healthID }) { continue }
                    database.workouts.append(record)
                }
                database.workouts.sort { $0.start > $1.start }
            }
        } catch {
            return
        }
    }

    private func mutate(_ body: (inout Database) -> Void) {
        var copy = database
        body(&copy)
        database = copy
        AppFiles.save(copy, name: filename)
    }
}

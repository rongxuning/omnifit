import Foundation

struct Database: Codable {
    var accounts: [Account] = []
    var sessionAccountID: UUID?
    var workouts: [WorkoutRecord] = []
    var posts: [SocialPost] = []
    var metricOrder: [LiveBlock] = LiveBlock.standard
    var selectedTeammateIDs: [String] = []
    var seeded: Bool = false
}

enum AppFiles {
    static func directory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = base.appendingPathComponent("omnifit", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func file(_ name: String) throws -> URL {
        try directory().appendingPathComponent(name)
    }

    static func load(_ name: String) -> Database? {
        guard let url = try? file(name),
              let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Database.self, from: data)
    }

    static func save(_ database: Database, name: String) {
        guard let url = try? file(name) else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(database) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

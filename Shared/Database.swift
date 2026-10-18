import Foundation

struct Database {
    var accounts: [Account] = []
    var sessionAccountID: UUID?
    var workouts: [WorkoutRecord] = []
    var posts: [SocialPost] = []
    var metricOrder: [LiveBlock] = LiveBlock.standard
    var selectedTeammateIDs: [String] = []
    var seeded: Bool = false
    /// Planned routes saved on this device. Missing in older files.
    var routes: [SavedRoute] = []
}

extension Database: Codable {
    private enum CodingKeys: String, CodingKey {
        case accounts, sessionAccountID, workouts, posts, metricOrder, selectedTeammateIDs, seeded, routes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accounts = try container.decodeIfPresent([Account].self, forKey: .accounts) ?? []
        sessionAccountID = try container.decodeIfPresent(UUID.self, forKey: .sessionAccountID)
        workouts = try container.decodeIfPresent([WorkoutRecord].self, forKey: .workouts) ?? []
        posts = try container.decodeIfPresent([SocialPost].self, forKey: .posts) ?? []
        metricOrder = try container.decodeIfPresent([LiveBlock].self, forKey: .metricOrder) ?? LiveBlock.standard
        selectedTeammateIDs = try container.decodeIfPresent([String].self, forKey: .selectedTeammateIDs) ?? []
        seeded = try container.decodeIfPresent(Bool.self, forKey: .seeded) ?? false
        routes = try container.decodeIfPresent([SavedRoute].self, forKey: .routes) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accounts, forKey: .accounts)
        try container.encodeIfPresent(sessionAccountID, forKey: .sessionAccountID)
        try container.encode(workouts, forKey: .workouts)
        try container.encode(posts, forKey: .posts)
        try container.encode(metricOrder, forKey: .metricOrder)
        try container.encode(selectedTeammateIDs, forKey: .selectedTeammateIDs)
        try container.encode(seeded, forKey: .seeded)
        try container.encode(routes, forKey: .routes)
    }
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

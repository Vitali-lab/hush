import Foundation

struct HistoryEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var text: String
    var date: Date = Date()
    var appName: String?
    var duration: Double = 0
    var model: String = ""
}

final class HistoryStore {
    private let limit = 500

    func load() -> [HistoryEntry] {
        guard let data = try? Data(contentsOf: AppPaths.historyFile) else { return [] }
        return (try? JSONDecoder().decode([HistoryEntry].self, from: data)) ?? []
    }

    func save(_ entries: [HistoryEntry]) {
        let trimmed = Array(entries.prefix(limit))
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        try? data.write(to: AppPaths.historyFile, options: .atomic)
    }
}

import Foundation

enum AppPaths {
    static let support: URL = {
        let fileManager = FileManager.default
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let current = base.appendingPathComponent("Hush", isDirectory: true)
        let legacy = base.appendingPathComponent("Sotto", isDirectory: true)

        // Carry models and history over from the previous name.
        if !fileManager.fileExists(atPath: current.path),
           fileManager.fileExists(atPath: legacy.path) {
            try? fileManager.moveItem(at: legacy, to: current)
        }

        try? fileManager.createDirectory(at: current, withIntermediateDirectories: true)
        return current
    }()

    static let models: URL = {
        let url = support.appendingPathComponent("Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static var settingsFile: URL { support.appendingPathComponent("settings.json") }
    static var historyFile: URL { support.appendingPathComponent("history.json") }
}

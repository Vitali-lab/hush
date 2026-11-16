import Foundation

enum Log {
    private static let enabled = CommandLine.arguments.contains("--verbose")

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    static func info(_ message: String) {
        guard enabled else { return }
        print("[\(formatter.string(from: Date()))] \(message)")
        fflush(stdout)
    }

    static func error(_ message: String) {
        guard enabled else { return }
        print("[\(formatter.string(from: Date()))] ERROR \(message)")
        fflush(stdout)
    }
}

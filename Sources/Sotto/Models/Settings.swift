import Foundation

enum HotkeyChoice: String, Codable, CaseIterable, Identifiable {
    case fnHold
    case rightOptionHold
    case fnDoubleTap
    case controlOptionSpace

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fnHold: return "Hold Fn"
        case .rightOptionHold: return "Hold Right ⌥"
        case .fnDoubleTap: return "Double-tap Fn"
        case .controlOptionSpace: return "⌃⌥Space"
        }
    }

    var detail: String {
        switch self {
        case .fnHold: return "Press and hold, speak, release."
        case .rightOptionHold: return "Press and hold, speak, release."
        case .fnDoubleTap: return "Tap twice to start, tap once to stop."
        case .controlOptionSpace: return "Press to start, press again to stop."
        }
    }

    var isHold: Bool {
        self == .fnHold || self == .rightOptionHold
    }
}

enum LanguageChoice: String, Codable, CaseIterable, Identifiable {
    case auto
    case russian
    case english

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "Auto-detect"
        case .russian: return "Russian"
        case .english: return "English"
        }
    }

    var whisperCode: String? {
        switch self {
        case .auto: return nil
        case .russian: return "ru"
        case .english: return "en"
        }
    }
}

struct DictionaryEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var spoken: String = ""
    var written: String = ""
}

struct Snippet: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var trigger: String = ""
    var expansion: String = ""
}

struct AppSettings: Codable, Equatable {
    var hotkey: HotkeyChoice = .fnHold
    var language: LanguageChoice = .auto
    var modelID: String = ModelCatalog.defaultID
    var autoPaste: Bool = true
    var removeFillers: Bool = true
    var playFeedbackSound: Bool = false
    var launchAtLogin: Bool = false
    var maxSeconds: Double = 180
    var dictionary: [DictionaryEntry] = []
    var snippets: [Snippet] = []
    var hasCompletedSetup: Bool = false

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hotkey = try container.decodeIfPresent(HotkeyChoice.self, forKey: .hotkey) ?? .fnHold
        language = try container.decodeIfPresent(LanguageChoice.self, forKey: .language) ?? .auto
        modelID = try container.decodeIfPresent(String.self, forKey: .modelID) ?? ModelCatalog.defaultID
        autoPaste = try container.decodeIfPresent(Bool.self, forKey: .autoPaste) ?? true
        removeFillers = try container.decodeIfPresent(Bool.self, forKey: .removeFillers) ?? true
        playFeedbackSound = try container.decodeIfPresent(Bool.self, forKey: .playFeedbackSound) ?? false
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        maxSeconds = try container.decodeIfPresent(Double.self, forKey: .maxSeconds) ?? 180
        dictionary = try container.decodeIfPresent([DictionaryEntry].self, forKey: .dictionary) ?? []
        snippets = try container.decodeIfPresent([Snippet].self, forKey: .snippets) ?? []
        hasCompletedSetup = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedSetup) ?? false
    }
}

final class SettingsStore {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    func load() -> AppSettings {
        guard let data = try? Data(contentsOf: AppPaths.settingsFile) else { return AppSettings() }
        return (try? JSONDecoder().decode(AppSettings.self, from: data)) ?? AppSettings()
    }

    func save(_ settings: AppSettings) {
        guard let data = try? encoder.encode(settings) else { return }
        try? data.write(to: AppPaths.settingsFile, options: .atomic)
    }
}

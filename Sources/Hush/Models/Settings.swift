import Foundation

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
    var language: AppLanguage = .systemDefault
    var theme: AppTheme = .system
    var hotkey: HotkeyBinding = .defaultBinding
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

        if let raw = try container.decodeIfPresent(String.self, forKey: .language) {
            switch raw {
            case "russian":
                language = .ru
            case "english":
                language = .en
            default:
                language = AppLanguage(rawValue: raw) ?? .systemDefault
            }
        } else {
            language = .systemDefault
        }

        theme = try container.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .system

        if let binding = try? container.decode(HotkeyBinding.self, forKey: .hotkey) {
            hotkey = binding
        } else if let legacy = try? container.decode(String.self, forKey: .hotkey) {
            hotkey = HotkeyBinding.legacy(legacy)
        } else {
            hotkey = .defaultBinding
        }

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

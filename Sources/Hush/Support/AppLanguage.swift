import Foundation

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case en
    case ru

    var id: String { rawValue }

    /// Interface and dictation use the same language on purpose: speaking
    /// Russian while the app is in English is the main source of bad guesses.
    var whisperCode: String { rawValue }

    var displayName: String {
        switch self {
        case .en: return "English"
        case .ru: return "Русский"
        }
    }

    var shortName: String {
        switch self {
        case .en: return "EN"
        case .ru: return "RU"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }

    static var systemDefault: AppLanguage {
        let code = Locale.current.language.languageCode?.identifier
        return code == "ru" ? .ru : .en
    }
}

/// Tiny inline localizer: `t("General", "Основное")`.
struct Loc {
    let lang: AppLanguage

    init(_ lang: AppLanguage) {
        self.lang = lang
    }

    func callAsFunction(_ english: String, _ russian: String) -> String {
        lang == .ru ? russian : english
    }
}

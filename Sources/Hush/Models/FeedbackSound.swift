import Foundation

enum FeedbackSound: String, Codable, CaseIterable, Identifiable {
    case chime
    case bloom
    case pluck
    case tick

    var id: String { rawValue }

    func name(_ lang: AppLanguage) -> String {
        let t = Loc(lang)
        switch self {
        case .chime: return t("Chime", "Колокольчик")
        case .bloom: return t("Bloom", "Блум")
        case .pluck: return t("Pluck", "Щипок")
        case .tick: return t("Tick", "Тик")
        }
    }

    func detail(_ lang: AppLanguage) -> String {
        let t = Loc(lang)
        switch self {
        case .chime: return t("Soft two-note chime", "Мягкий двухнотный звон")
        case .bloom: return t("Gentle rising tone", "Тихо восходящий тон")
        case .pluck: return t("Short wooden pluck", "Короткий деревянный щипок")
        case .tick: return t("Tiny click", "Едва слышный щелчок")
        }
    }
}

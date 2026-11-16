import AppKit
import SwiftUI

struct ThemePalette: Equatable {
    let accent: Color
    let accentBright: Color
    let pink: Color
}

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system
    case daylight
    case sand
    case graphite
    case midnight

    var id: String { rawValue }

    func name(_ lang: AppLanguage) -> String {
        let t = Loc(lang)
        switch self {
        case .system: return t("System", "Системная")
        case .daylight: return t("Daylight", "Светлая")
        case .sand: return t("Sand", "Песочная")
        case .graphite: return t("Graphite", "Графит")
        case .midnight: return t("Midnight", "Полночь")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .daylight, .sand: return .light
        case .graphite, .midnight: return .dark
        }
    }

    var appearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .daylight, .sand: return NSAppearance(named: .aqua)
        case .graphite, .midnight: return NSAppearance(named: .darkAqua)
        }
    }

    var isDark: Bool {
        switch self {
        case .daylight, .sand: return false
        case .system, .graphite, .midnight: return true
        }
    }

    var palette: ThemePalette {
        switch self {
        case .system:
            return ThemePalette(
                accent: Color(red: 0.45, green: 0.36, blue: 1.0),
                accentBright: Color(red: 0.65, green: 0.47, blue: 1.0),
                pink: Color(red: 0.96, green: 0.38, blue: 0.64)
            )
        case .daylight:
            return ThemePalette(
                accent: Color(red: 0.16, green: 0.40, blue: 0.98),
                accentBright: Color(red: 0.40, green: 0.62, blue: 1.0),
                pink: Color(red: 1.0, green: 0.42, blue: 0.62)
            )
        case .sand:
            return ThemePalette(
                accent: Color(red: 0.74, green: 0.42, blue: 0.22),
                accentBright: Color(red: 0.89, green: 0.62, blue: 0.36),
                pink: Color(red: 0.84, green: 0.38, blue: 0.45)
            )
        case .graphite:
            return ThemePalette(
                accent: Color(red: 0.42, green: 0.55, blue: 1.0),
                accentBright: Color(red: 0.60, green: 0.72, blue: 1.0),
                pink: Color(red: 0.78, green: 0.45, blue: 0.86)
            )
        case .midnight:
            return ThemePalette(
                accent: Color(red: 0.49, green: 0.36, blue: 1.0),
                accentBright: Color(red: 0.67, green: 0.48, blue: 1.0),
                pink: Color(red: 0.96, green: 0.38, blue: 0.64)
            )
        }
    }
}

@MainActor
enum ThemeRuntime {
    static var palette: ThemePalette = AppTheme.system.palette

    static func apply(_ theme: AppTheme) {
        palette = theme.palette
        NSApp?.appearance = theme.appearance
    }
}

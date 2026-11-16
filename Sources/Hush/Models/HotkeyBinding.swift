import AppKit

enum HotkeyMode: String, Codable, CaseIterable, Identifiable {
    case hold
    case toggle

    var id: String { rawValue }

    func title(_ lang: AppLanguage) -> String {
        let t = Loc(lang)
        switch self {
        case .hold: return t("Hold", "Удерживать")
        case .toggle: return t("Press to toggle", "Нажатие — старт/стоп")
        }
    }
}

struct HotkeyBinding: Codable, Equatable, Hashable {
    var keyCode: UInt16
    var modifiers: UInt
    var mode: HotkeyMode
    var doubleTap: Bool
    var character: String

    init(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags = [],
        mode: HotkeyMode = .hold,
        doubleTap: Bool = false,
        character: String = ""
    ) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(Self.interestingModifiers).rawValue
        self.mode = mode
        self.doubleTap = doubleTap
        self.character = character
    }

    static let interestingModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift, .function]

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiers)
    }

    var isModifierOnly: Bool {
        Self.modifierKeyCodes.contains(keyCode)
    }

    var isFunctionKey: Bool {
        Self.functionKeyCodes.contains(keyCode)
    }

    var isValid: Bool {
        if isFunctionKey || isModifierOnly { return true }
        return !modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty
    }

    // MARK: - Matching

    func matches(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        guard self.keyCode == keyCode else { return false }
        let relevant = flags.intersection(Self.interestingModifiers)
        return relevant == modifierFlags.intersection(Self.interestingModifiers)
    }

    /// Some modifier keys need a physical distinction between left and right.
    func modifierIsDown(_ flags: NSEvent.ModifierFlags) -> Bool {
        switch keyCode {
        case 63: return flags.contains(.function)
        case 54, 55: return flags.contains(.command)
        case 58, 61: return flags.contains(.option)
        case 59, 62: return flags.contains(.control)
        case 56, 60: return flags.contains(.shift)
        default: return false
        }
    }

    // MARK: - Display

    func display(_ lang: AppLanguage) -> String {
        let t = Loc(lang)

        if isModifierOnly {
            switch keyCode {
            case 63: return doubleTap ? "Fn ×2" : "Fn"
            case 61: return t("Right ⌥", "Правый ⌥")
            case 58: return "⌥"
            case 54: return t("Right ⌘", "Правый ⌘")
            case 55: return "⌘"
            case 62: return t("Right ⌃", "Правый ⌃")
            case 59: return "⌃"
            case 60: return t("Right ⇧", "Правый ⇧")
            case 56: return "⇧"
            default: return keyLabel(lang)
            }
        }

        var result = ""
        if modifierFlags.contains(.function) { result += "fn " }
        if modifierFlags.contains(.control) { result += "⌃" }
        if modifierFlags.contains(.option) { result += "⌥" }
        if modifierFlags.contains(.shift) { result += "⇧" }
        if modifierFlags.contains(.command) { result += "⌘" }
        return result + keyLabel(lang)
    }

    private func keyLabel(_ lang: AppLanguage) -> String {
        let t = Loc(lang)
        switch keyCode {
        case 49: return t("Space", "Пробел")
        case 36: return "↩"
        case 48: return "⇥"
        case 51: return "⌫"
        case 117: return "⌦"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 115: return "↖"
        case 119: return "↘"
        case 116: return "⇞"
        case 121: return "⇟"
        default:
            if let function = Self.functionKeyNames[keyCode] { return function }
            if character.isEmpty { return "#\(keyCode)" }
            return character.uppercased()
        }
    }

    // MARK: - Presets

    static let fnHold = HotkeyBinding(
        keyCode: 63,
        modifiers: .function,
        mode: .hold
    )

    static let rightOptionHold = HotkeyBinding(
        keyCode: 61,
        modifiers: .option,
        mode: .hold
    )

    static let fnDoubleTap = HotkeyBinding(
        keyCode: 63,
        modifiers: .function,
        mode: .toggle,
        doubleTap: true
    )

    static let controlOptionSpace = HotkeyBinding(
        keyCode: 49,
        modifiers: [.control, .option],
        mode: .toggle,
        character: " "
    )

    static let defaultBinding = fnHold

    static var presets: [HotkeyBinding] {
        [fnHold, rightOptionHold, fnDoubleTap, controlOptionSpace]
    }

    static func legacy(_ raw: String) -> HotkeyBinding {
        switch raw {
        case "rightOptionHold": return .rightOptionHold
        case "fnDoubleTap": return .fnDoubleTap
        case "controlOptionSpace": return .controlOptionSpace
        default: return .fnHold
        }
    }

    // MARK: - Key tables

    static func isModifierKey(_ keyCode: UInt16) -> Bool {
        modifierKeyCodes.contains(keyCode)
    }

    private static let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]

    private static let functionKeyCodes: Set<UInt16> = [
        122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90
    ]

    private static let functionKeyNames: [UInt16: String] = [
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7",
        100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13",
        107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20"
    ]
}

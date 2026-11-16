import AppKit
import Foundation

enum SelfTest {
    static func run() {
        var failures = 0

        func check(_ condition: Bool, _ name: String) {
            print("\(condition ? "ok  " : "FAIL") | \(name)")
            if !condition { failures += 1 }
        }

        var settings = AppSettings()
        settings.dictionary = [
            DictionaryEntry(spoken: "кубернетес", written: "Kubernetes"),
            DictionaryEntry(spoken: "доктор смит", written: "Dr. Smith")
        ]
        settings.snippets = [
            Snippet(trigger: "мой имейл", expansion: "hello@example.com")
        ]

        let cases: [(String, String)] = [
            ("ээ привет кубернетес как дела", "Привет Kubernetes как дела"),
            ("Мой имейл.", "hello@example.com"),
            ("это доктор смит говорит", "Это Dr. Smith говорит"),
            ("example.com не трогаем", "Example.com не трогаем"),
            ("привет.как дела", "Привет.как дела")
        ]

        for (input, expected) in cases {
            let actual = TextProcessor.process(input, settings: settings)
            check(actual == expected, "text: \(input) -> \(actual)")
        }

        let legacyJSON = """
        {"hotkey":"fnHold","language":"russian","theme":"midnight"}
        """
        if let data = legacyJSON.data(using: .utf8),
           let migrated = try? JSONDecoder().decode(AppSettings.self, from: data) {
            check(migrated.hotkey == .fnHold, "legacy hotkey migrates")
            check(migrated.language == .ru, "legacy language migrates")
            check(migrated.theme == .midnight, "theme decodes")
        } else {
            check(false, "legacy settings decode")
        }

        check(HotkeyBinding.fnHold.display(.en) == "Fn", "Fn display")
        check(HotkeyBinding.controlOptionSpace.display(.ru) == "⌃⌥Пробел", "space display")
        check(
            HotkeyBinding(keyCode: 2, modifiers: [.command, .shift], character: "d").display(.en) == "⇧⌘D",
            "custom combo display"
        )
        check(HotkeyBinding(keyCode: 2, character: "d").isValid, "plain letter allowed")
        check(HotkeyBinding(keyCode: 96).isValid, "function key allowed")

        check(HotkeyBinding.fnHold.matches(keyCode: 63, flags: .function), "Fn matches")
        check(
            !HotkeyBinding.fnHold.matches(keyCode: 63, flags: [.function, .shift]),
            "Fn plus shift does not match"
        )
        check(
            HotkeyBinding.controlOptionSpace.matches(keyCode: 49, flags: [.control, .option, .capsLock]),
            "caps lock is ignored"
        )
        check(
            HotkeyBinding(keyCode: 2, modifiers: [.command, .shift]).matches(keyCode: 2, flags: [.command, .shift, .capsLock]),
            "custom combo matches"
        )
        check(
            !HotkeyBinding(keyCode: 2, modifiers: [.command]).matches(keyCode: 2, flags: [.option]),
            "wrong modifier does not match"
        )

        var roundTrip = AppSettings()
        roundTrip.language = .en
        roundTrip.theme = .sand
        roundTrip.hotkey = HotkeyBinding(keyCode: 49, modifiers: [.control, .option], mode: .toggle, character: " ")
        if let data = try? JSONEncoder().encode(roundTrip),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            check(decoded == roundTrip, "settings round-trip")
        } else {
            check(false, "settings round-trip")
        }

        print(failures == 0 ? "All checks passed." : "\(failures) check(s) failed.")
        exit(failures == 0 ? 0 : 1)
    }
}

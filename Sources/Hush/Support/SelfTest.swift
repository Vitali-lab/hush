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
        check(!HotkeyBinding(keyCode: 2, character: "d").isValid, "plain letter rejected")
        check(HotkeyBinding(keyCode: 96).isValid, "function key allowed")

        print(failures == 0 ? "All checks passed." : "\(failures) check(s) failed.")
        exit(failures == 0 ? 0 : 1)
    }
}

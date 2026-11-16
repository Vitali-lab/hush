import Foundation

enum SelfTest {
    static func run() {
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
            ("привет.как дела", "Привет.как дела")        ]

        var failures = 0
        for (input, expected) in cases {
            let actual = TextProcessor.process(input, settings: settings)
            let ok = actual == expected
            if !ok { failures += 1 }
            print("\(ok ? "ok  " : "FAIL") | \(input) -> \(actual)")
            if !ok { print("       expected: \(expected)") }
        }

        print(failures == 0 ? "All text checks passed." : "\(failures) text check(s) failed.")
        exit(failures == 0 ? 0 : 1)
    }
}

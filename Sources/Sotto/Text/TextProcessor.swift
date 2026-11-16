import Foundation

enum TextProcessor {
    static func process(_ raw: String, settings: AppSettings) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        text = stripArtifacts(text)
        if settings.removeFillers {
            text = removeFillers(text)
        }
        text = normalizeSpacing(text)
        text = capitalizeSentences(text)
        text = applyDictionary(text, entries: settings.dictionary)
        text = applySnippets(text, snippets: settings.snippets)

        return text
    }

    // MARK: - Steps

    private static func stripArtifacts(_ text: String) -> String {
        let patterns = [
            "\\[(?:BLANK_AUDIO|MUSIC|APPLAUSE|LAUGHTER|NOISE|SILENCE)\\]",
            "\\((?:music|applause|laughter|noise|silence)\\)"
        ]
        var result = text
        for pattern in patterns {
            result = result.replacingOccurrences(
                of: pattern,
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func removeFillers(_ text: String) -> String {
        let filler = "(?:э{1,3}|эм{1,2}|мм{1,3}|аа{1,3}|um{1,2}|uh{1,2}|erm|hmm|mm)"
        let pattern = "(?<![\\p{L}\\p{N}])" + filler + "(?![\\p{L}\\p{N}])"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }
        var result = regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: ""
        )
        result = result.replacingOccurrences(of: " ,", with: ",")
        result = result.replacingOccurrences(of: " \\.", with: ".")
        result = result.replacingOccurrences(of: "  ", with: " ")
        return result
    }

    private static func applyDictionary(_ text: String, entries: [DictionaryEntry]) -> String {
        let active = entries.filter { !$0.spoken.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !active.isEmpty else { return text }

        var result = text
        for entry in active {
            let spoken = entry.spoken.trimmingCharacters(in: .whitespaces)
            let written = entry.written.trimmingCharacters(in: .whitespaces)
            let replacement = written.isEmpty ? spoken : written
            let escaped = NSRegularExpression.escapedPattern(for: spoken)
            let pattern = "(?<![\\p{L}\\p{N}])\(escaped)(?![\\p{L}\\p{N}])"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: NSRegularExpression.escapedTemplate(for: replacement)
            )
        }
        return result
    }

    private static func applySnippets(_ text: String, snippets: [Snippet]) -> String {
        let normalized = normalizeForCompare(text)
        guard !normalized.isEmpty else { return text }

        for snippet in snippets {
            let trigger = normalizeForCompare(snippet.trigger)
            guard !trigger.isEmpty, trigger == normalized else { continue }
            let expansion = snippet.expansion.trimmingCharacters(in: .whitespacesAndNewlines)
            if !expansion.isEmpty { return expansion }
        }
        return text
    }

    private static func normalizeForCompare(_ text: String) -> String {
        let allowed = text.lowercased().filter { $0.isLetter || $0.isNumber || $0 == " " }
        return allowed
            .split(separator: " ")
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func normalizeSpacing(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\s+([,.!?;:])", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\s+([)»])", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "([(«])\\s+", with: "$1", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func capitalizeSentences(_ text: String) -> String {
        guard let first = text.first else { return text }
        var result = String(first).uppercased() + text.dropFirst()

        let pattern = "([.!?]\\s+)(\\p{Ll})"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                guard let prefixRange = Range(match.range(at: 1), in: result),
                      let letterRange = Range(match.range(at: 2), in: result) else { continue }
                let letter = result[letterRange]
                result.replaceSubrange(letterRange, with: letter.uppercased())
                _ = prefixRange
            }
        }
        return result
    }
}

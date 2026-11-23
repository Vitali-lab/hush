using System.Text;
using System.Text.RegularExpressions;

namespace Hush.Core;

public static class TextProcessor
{
    public static string Process(string raw, AppSettings settings)
    {
        var text = raw.Trim();

        text = StripArtifacts(text);
        if (settings.RemoveFillers) text = RemoveFillers(text);
        text = NormalizeSpacing(text);
        text = CapitalizeSentences(text);
        text = ApplyDictionary(text, settings.Dictionary);
        text = ApplySnippets(text, settings.Snippets);

        return text.Trim();
    }

    private static string StripArtifacts(string text)
    {
        var patterns = new[]
        {
            @"\[(?:BLANK_AUDIO|MUSIC|APPLAUSE|LAUGHTER|NOISE|SILENCE)\]",
            @"\((?:music|applause|laughter|noise|silence)\)"
        };

        foreach (var pattern in patterns)
            text = Regex.Replace(text, pattern, " ", RegexOptions.IgnoreCase);

        return text.Trim();
    }

    private static string RemoveFillers(string text)
    {
        const string filler = @"(?:э{1,3}|эм{1,2}|мм{1,3}|аа{1,3}|um{1,2}|uh{1,2}|erm|hmm|mm)";
        var pattern = @"(?<![\p{L}\p{N}])" + filler + @"(?![\p{L}\p{N}])";

        var result = Regex.Replace(text, pattern, "", RegexOptions.IgnoreCase);
        result = result.Replace(" ,", ",").Replace(" .", ".");
        return Regex.Replace(result, @" {2,}", " ");
    }

    private static string NormalizeSpacing(string text)
    {
        var result = Regex.Replace(text, @"\s+", " ");
        result = Regex.Replace(result, @"\s+([,.!?;:])", "$1");
        result = Regex.Replace(result, @"\s+([)»])", "$1");
        result = Regex.Replace(result, @"([(«])\s+", "$1");
        return result.Trim();
    }

    private static string CapitalizeSentences(string text)
    {
        if (text.Length == 0) return text;

        var result = char.ToUpperInvariant(text[0]) + text[1..];
        return Regex.Replace(result, @"([.!?]\s+)(\p{Ll})",
            match => match.Groups[1].Value + match.Groups[2].Value.ToUpperInvariant());
    }

    private static string ApplyDictionary(string text, IReadOnlyList<DictionaryEntry> entries)
    {
        var result = text;

        foreach (var entry in entries)
        {
            var spoken = entry.Spoken.Trim();
            if (spoken.Length == 0) continue;

            var written = entry.Written.Trim();
            if (written.Length == 0) written = spoken;

            var pattern = @"(?<![\p{L}\p{N}])" + Regex.Escape(spoken) + @"(?![\p{L}\p{N}])";
            result = Regex.Replace(result, pattern, _ => written, RegexOptions.IgnoreCase);
        }

        return result;
    }

    private static string ApplySnippets(string text, IReadOnlyList<Snippet> snippets)
    {
        var normalized = NormalizeForCompare(text);
        if (normalized.Length == 0) return text;

        foreach (var snippet in snippets)
        {
            var trigger = NormalizeForCompare(snippet.Trigger);
            if (trigger.Length == 0 || !string.Equals(trigger, normalized, StringComparison.Ordinal))
                continue;

            var expansion = snippet.Expansion.Trim();
            if (expansion.Length > 0) return expansion;
        }

        return text;
    }

    private static string NormalizeForCompare(string text)
    {
        var builder = new StringBuilder(text.Length);

        foreach (var ch in text.ToLowerInvariant())
        {
            if (char.IsLetterOrDigit(ch) || ch == ' ')
                builder.Append(ch);
        }

        return Regex.Replace(builder.ToString(), @"\s+", " ").Trim();
    }
}

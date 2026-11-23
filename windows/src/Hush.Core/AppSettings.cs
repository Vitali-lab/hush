using System.Text.Json;
using System.Text.Json.Serialization;

namespace Hush.Core;

public sealed class DictionaryEntry
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Spoken { get; set; } = "";
    public string Written { get; set; } = "";
}

public sealed class Snippet
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Trigger { get; set; } = "";
    public string Expansion { get; set; } = "";
}

public sealed class AppSettings
{
    public AppLanguage Language { get; set; } = SystemDefaultLanguage();
    public AppTheme Theme { get; set; } = AppTheme.System;
    public HotkeyBinding Hotkey { get; set; } = HotkeyBinding.Default;
    public string ModelId { get; set; } = ModelCatalog.DefaultId;
    public bool AutoPaste { get; set; } = true;
    public bool RemoveFillers { get; set; } = true;
    public bool PlayFeedbackSound { get; set; }
    public FeedbackSound FeedbackSound { get; set; } = FeedbackSound.Chime;
    public bool LaunchAtLogin { get; set; }
    public int MaxSeconds { get; set; } = 180;
    public List<DictionaryEntry> Dictionary { get; set; } = [];
    public List<Snippet> Snippets { get; set; } = [];
    public bool HasCompletedSetup { get; set; }

    public static AppLanguage SystemDefaultLanguage() =>
        System.Globalization.CultureInfo.CurrentUICulture.TwoLetterISOLanguageName == "ru"
            ? AppLanguage.Russian
            : AppLanguage.English;
}

public static class JsonDefaults
{
    public static readonly JsonSerializerOptions Options = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true,
        Converters = { new JsonStringEnumConverter() }
    };
}

public sealed class SettingsStore
{
    private readonly string _path;

    public SettingsStore(string path) => _path = path;

    public AppSettings Load()
    {
        try
        {
            if (!File.Exists(_path)) return new AppSettings();
            var json = File.ReadAllText(_path);
            return JsonSerializer.Deserialize<AppSettings>(json, JsonDefaults.Options) ?? new AppSettings();
        }
        catch
        {
            return new AppSettings();
        }
    }

    public void Save(AppSettings settings)
    {
        try
        {
            var directory = Path.GetDirectoryName(_path);
            if (!string.IsNullOrEmpty(directory)) Directory.CreateDirectory(directory);
            var json = JsonSerializer.Serialize(settings, JsonDefaults.Options);
            var temp = _path + ".tmp";
            File.WriteAllText(temp, json);
            File.Move(temp, _path, true);
        }
        catch
        {
            // Settings are not critical enough to crash the app.
        }
    }
}

namespace Hush.Core;

public enum AppLanguage
{
    English,
    Russian
}

public enum AppTheme
{
    System,
    Daylight,
    Sand,
    Graphite,
    Midnight
}

public enum FeedbackSound
{
    Chime,
    Bloom,
    Pluck,
    Tick
}

[Flags]
public enum HotkeyModifiers
{
    None = 0,
    Control = 1,
    Alt = 2,
    Shift = 4,
    Win = 8
}

public enum HotkeyMode
{
    Hold,
    Toggle
}

public static class L10n
{
    public static string T(AppLanguage language, string english, string russian) =>
        language == AppLanguage.Russian ? russian : english;

    public static string LanguageName(AppLanguage language) =>
        language == AppLanguage.Russian ? "Русский" : "English";

    public static string ThemeName(AppTheme theme, AppLanguage language) => theme switch
    {
        AppTheme.System => T(language, "System", "Системная"),
        AppTheme.Daylight => T(language, "Daylight", "Светлая"),
        AppTheme.Sand => T(language, "Sand", "Песочная"),
        AppTheme.Graphite => T(language, "Graphite", "Графит"),
        AppTheme.Midnight => T(language, "Midnight", "Полночь"),
        _ => theme.ToString()
    };

    public static string SoundName(FeedbackSound sound, AppLanguage language) => sound switch
    {
        FeedbackSound.Chime => T(language, "Chime", "Колокольчик"),
        FeedbackSound.Bloom => T(language, "Bloom", "Блум"),
        FeedbackSound.Pluck => T(language, "Pluck", "Щипок"),
        FeedbackSound.Tick => T(language, "Tick", "Тик"),
        _ => sound.ToString()
    };

    public static string SoundDetail(FeedbackSound sound, AppLanguage language) => sound switch
    {
        FeedbackSound.Chime => T(language, "Soft two-note chime", "Мягкий двухнотный звон"),
        FeedbackSound.Bloom => T(language, "Gentle rising tone", "Тихо восходящий тон"),
        FeedbackSound.Pluck => T(language, "Short wooden pluck", "Короткий деревянный щипок"),
        FeedbackSound.Tick => T(language, "Tiny click", "Едва слышный щелчок"),
        _ => ""
    };
}

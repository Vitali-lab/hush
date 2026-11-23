using Hush.Core;

namespace Hush.Windows.Services;

public static class AppPaths
{
    public static string Root { get; } = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "Hush");

    public static string Models { get; } = Path.Combine(Root, "models");
    public static string SettingsFile => Path.Combine(Root, "settings.json");
    public static string HistoryFile => Path.Combine(Root, "history.json");

    public static string ModelPath(ModelSpec model) => Path.Combine(Models, model.FileName);

    public static void Ensure()
    {
        Directory.CreateDirectory(Root);
        Directory.CreateDirectory(Models);
    }

    public static bool IsModelInstalled(ModelSpec model)
    {
        var path = ModelPath(model);
        if (!File.Exists(path)) return false;

        // Downloads are written to .part and moved only when complete.
        return new FileInfo(path).Length > 1_000_000;
    }

    public static long ModelSize(ModelSpec model)
    {
        var path = ModelPath(model);
        return File.Exists(path) ? new FileInfo(path).Length : 0;
    }
}

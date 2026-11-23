using System.Text.Json;

namespace Hush.Core;

public sealed class HistoryEntry
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Text { get; set; } = "";
    public DateTimeOffset Date { get; set; } = DateTimeOffset.Now;
    public string? AppName { get; set; }
    public double Duration { get; set; }
    public string Model { get; set; } = "";
}

public sealed class HistoryStore
{
    private readonly string _path;

    public HistoryStore(string path) => _path = path;

    public List<HistoryEntry> Load()
    {
        try
        {
            if (!File.Exists(_path)) return [];
            var json = File.ReadAllText(_path);
            return JsonSerializer.Deserialize<List<HistoryEntry>>(json, JsonDefaults.Options) ?? [];
        }
        catch
        {
            return [];
        }
    }

    public void Save(IReadOnlyList<HistoryEntry> entries)
    {
        try
        {
            var directory = Path.GetDirectoryName(_path);
            if (!string.IsNullOrEmpty(directory)) Directory.CreateDirectory(directory);
            var json = JsonSerializer.Serialize(entries.Take(500), JsonDefaults.Options);
            var temp = _path + ".tmp";
            File.WriteAllText(temp, json);
            File.Move(temp, _path, true);
        }
        catch
        {
            // History is optional.
        }
    }
}

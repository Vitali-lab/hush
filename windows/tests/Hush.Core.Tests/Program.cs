using Hush.Core;

var failures = 0;

void Check(bool condition, string name)
{
    Console.WriteLine($"{(condition ? "ok  " : "FAIL")} | {name}");
    if (!condition) failures++;
}

var settings = new AppSettings
{
    Dictionary =
    [
        new DictionaryEntry { Spoken = "кубернетес", Written = "Kubernetes" },
        new DictionaryEntry { Spoken = "доктор смит", Written = "Dr. Smith" }
    ],
    Snippets =
    [
        new Snippet { Trigger = "мой имейл", Expansion = "hello@example.com" }
    ]
};

var cases = new (string Input, string Expected)[]
{
    ("ээ привет кубернетес как дела", "Привет Kubernetes как дела"),
    ("Мой имейл.", "hello@example.com"),
    ("это доктор смит говорит", "Это Dr. Smith говорит"),
    ("example.com не трогаем", "Example.com не трогаем"),
    ("привет.как дела", "Привет.как дела"),
    ("[MUSIC] привет", "Привет")
};

foreach (var (input, expected) in cases)
{
    var actual = TextProcessor.Process(input, settings);
    Check(actual == expected, $"text: {input} -> {actual}");
}

var json = System.Text.Json.JsonSerializer.Serialize(settings, JsonDefaults.Options);
var roundTrip = System.Text.Json.JsonSerializer.Deserialize<AppSettings>(json, JsonDefaults.Options)!;
Check(roundTrip.Dictionary.Count == 2 && roundTrip.Dictionary[0].Written == "Kubernetes", "settings round-trip");

Check(HotkeyBinding.RightAltHold.Display(AppLanguage.English) == "Right Alt", "right alt display");
Check(HotkeyBinding.CtrlAltSpace.Display(AppLanguage.English) == "Ctrl+Alt+Space", "ctrl-alt-space display");
Check(HotkeyBinding.CtrlAltSpace.Display(AppLanguage.Russian) == "Ctrl+Alt+Space", "ctrl-alt-space russian display");
Check(HotkeyBinding.F8Hold.Display(AppLanguage.English) == "F8", "F8 display");
Check(
    HotkeyBinding.CtrlAltSpace.Matches(0x20, HotkeyModifiers.Control | HotkeyModifiers.Alt),
    "ctrl-alt-space matches"
);
Check(
    !HotkeyBinding.CtrlAltSpace.Matches(0x20, HotkeyModifiers.Control),
    "ctrl-alt-space rejects missing alt"
);
Check(
    HotkeyBinding.RightAltHold.Matches(0xA5, HotkeyModifiers.None),
    "right alt matches"
);

Check(ModelCatalog.All.Count == 4, "four models");
Check(ModelCatalog.Default.FileName == "ggml-large-v3-turbo-q5_0.bin", "default model file");
Check(ModelCatalog.All.All(m => m.Url.StartsWith("https://huggingface.co/")), "model urls");

var tempDir = Path.Combine(Path.GetTempPath(), "hush-win-tests-" + Guid.NewGuid().ToString("N"));
var store = new SettingsStore(Path.Combine(tempDir, "settings.json"));
var loadedDefaults = store.Load();
Check(loadedDefaults.ModelId == ModelCatalog.DefaultId, "missing settings uses defaults");
store.Save(settings);
var loaded = store.Load();
Check(loaded.Dictionary.Count == 2, "settings persisted");
Directory.Delete(tempDir, true);

Console.WriteLine(failures == 0 ? "All checks passed." : $"{failures} check(s) failed.");
return failures == 0 ? 0 : 1;

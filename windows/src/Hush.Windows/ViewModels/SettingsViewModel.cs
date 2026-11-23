using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.Windows;
using Clipboard = System.Windows.Clipboard;
using Hush.Core;
using Hush.Windows.Services;

namespace Hush.Windows.ViewModels;

public sealed class SettingsViewModel : ObservableObject
{
    private readonly AppController _controller;
    private LanguageOption _selectedLanguage;
    private ThemeOption _selectedTheme;
    private SoundOption _selectedSound;
    private string _historyQuery = "";
    private bool _isCapturing;
    private string? _hotkeyError;

    public SettingsViewModel(AppController controller)
    {
        _controller = controller;

        Languages = [new LanguageOption(AppLanguage.English), new LanguageOption(AppLanguage.Russian)];
        Themes =
        [
            new ThemeOption(AppTheme.System, Language),
            new ThemeOption(AppTheme.Daylight, Language),
            new ThemeOption(AppTheme.Sand, Language),
            new ThemeOption(AppTheme.Graphite, Language),
            new ThemeOption(AppTheme.Midnight, Language)
        ];
        Sounds = Enum.GetValues<FeedbackSound>()
            .Select(s => new SoundOption(s, Language))
            .ToList();
        HotkeyPresets = HotkeyBinding.Presets
            .Select(b => new HotkeyPresetOption(b, Language))
            .ToList();
        Models = new ObservableCollection<ModelRowViewModel>(
            ModelCatalog.All.Select(m => new ModelRowViewModel(controller, m)));
        Dictionary = new ObservableCollection<DictionaryEntry>(controller.Settings.Dictionary);
        Snippets = new ObservableCollection<Snippet>(controller.Settings.Snippets);

        _selectedLanguage = Languages.First(l => l.Language == controller.Settings.Language);
        _selectedTheme = Themes.First(t => t.Theme == controller.Settings.Theme);
        _selectedSound = Sounds.First(s => s.Sound == controller.Settings.FeedbackSound);

        controller.SettingsChanged += OnSettingsChanged;
        controller.ModelChanged += OnModelChanged;
        controller.DownloadChanged += OnDownloadChanged;
        controller.HistoryChanged += RefreshHistory;
        controller.Hotkey.Captured += OnHotkeyCaptured;
        controller.Hotkey.CaptureCancelled += OnHotkeyCaptureCancelled;

        RefreshHistory();
        RefreshModelText();
    }

    public AppSettings Settings => _controller.Settings;
    public AppLanguage Language => Settings.Language;
    public string VersionText => $"v{AppInfo.Version}";

    public IReadOnlyList<LanguageOption> Languages { get; }
    public IReadOnlyList<ThemeOption> Themes { get; }
    public IReadOnlyList<SoundOption> Sounds { get; }
    public IReadOnlyList<HotkeyPresetOption> HotkeyPresets { get; }
    public ObservableCollection<ModelRowViewModel> Models { get; }
    public ObservableCollection<DictionaryEntry> Dictionary { get; }
    public ObservableCollection<Snippet> Snippets { get; }
    public ObservableCollection<HistoryEntry> FilteredHistory { get; } = [];

    public LanguageOption SelectedLanguage
    {
        get => _selectedLanguage;
        set
        {
            if (value == null || value == _selectedLanguage) return;
            _selectedLanguage = value;
            _controller.SetLanguage(value.Language);
            OnPropertyChanged();
        }
    }

    public ThemeOption SelectedTheme
    {
        get => _selectedTheme;
        set
        {
            if (value == null || value == _selectedTheme) return;
            _selectedTheme = value;
            _controller.SetTheme(value.Theme);
            OnPropertyChanged();
        }
    }

    public SoundOption SelectedSound
    {
        get => _selectedSound;
        set
        {
            if (value == null || value == _selectedSound) return;
            _selectedSound = value;
            _controller.SetSound(value.Sound);
            _controller.PreviewSound(value.Sound);
            OnPropertyChanged();
        }
    }

    public bool AutoPaste
    {
        get => Settings.AutoPaste;
        set
        {
            if (Settings.AutoPaste == value) return;
            Settings.AutoPaste = value;
            _controller.SaveSettings();
            OnPropertyChanged();
        }
    }

    public bool RemoveFillers
    {
        get => Settings.RemoveFillers;
        set
        {
            if (Settings.RemoveFillers == value) return;
            Settings.RemoveFillers = value;
            _controller.SaveSettings();
            OnPropertyChanged();
        }
    }

    public bool PlayFeedbackSound
    {
        get => Settings.PlayFeedbackSound;
        set
        {
            if (Settings.PlayFeedbackSound == value) return;
            Settings.PlayFeedbackSound = value;
            _controller.SaveSettings();
            OnPropertyChanged();
            OnPropertyChanged(nameof(ShowSoundPicker));
        }
    }

    public bool ShowSoundPicker => PlayFeedbackSound;

    public bool LaunchAtLogin
    {
        get => Settings.LaunchAtLogin;
        set
        {
            if (Settings.LaunchAtLogin == value) return;
            _controller.SetLaunchAtLogin(value);
            OnPropertyChanged();
        }
    }

    public bool IsHoldMode
    {
        get => Settings.Hotkey.Mode == HotkeyMode.Hold;
        set
        {
            if (!value) return;
            _controller.SetHotkeyMode(HotkeyMode.Hold);
            OnPropertyChanged();
            OnPropertyChanged(nameof(IsToggleMode));
        }
    }

    public bool IsToggleMode
    {
        get => Settings.Hotkey.Mode == HotkeyMode.Toggle;
        set
        {
            if (!value) return;
            _controller.SetHotkeyMode(HotkeyMode.Toggle);
            OnPropertyChanged();
            OnPropertyChanged(nameof(IsHoldMode));
        }
    }

    public string HotkeyDisplay => Settings.Hotkey.Display(Language);
    public string HotkeyText => IsCapturing ? Loc.Instance["ShortcutCapturing"] : HotkeyDisplay;
    public string HotkeyButtonText => IsCapturing ? Loc.Instance["ShortcutCancel"] : Loc.Instance["ShortcutRecord"];
    public bool IsCapturing
    {
        get => _isCapturing;
        private set
        {
            if (_isCapturing == value) return;
            _isCapturing = value;
            OnPropertyChanged();
            OnPropertyChanged(nameof(HotkeyText));
            OnPropertyChanged(nameof(HotkeyButtonText));
        }
    }

    public string? HotkeyError
    {
        get => _hotkeyError;
        private set
        {
            if (_hotkeyError == value) return;
            _hotkeyError = value;
            OnPropertyChanged();
        }
    }

    public bool NeedsSetup => !AppPaths.IsModelInstalled(_controller.CurrentModel);
    public string CurrentModelName => _controller.CurrentModel.Name(Language);
    public string ModelStatusTitle => _controller.ModelState switch
    {
        ModelLoadState.NotInstalled => Loc.Instance["ModelNotInstalled"],
        ModelLoadState.OnDisk => Loc.Instance["ModelOnDisk"],
        ModelLoadState.Loading => Loc.Instance["ModelLoading"],
        ModelLoadState.Ready => Loc.Instance["ModelReady"],
        _ => Loc.Instance["ModelError"]
    };

    public string ModelStatusDetail => _controller.ModelState switch
    {
        ModelLoadState.NotInstalled => Loc.Instance["ModelNotInstalledDetail"],
        ModelLoadState.OnDisk => Loc.Instance["ModelOnDiskDetail"],
        ModelLoadState.Loading => Loc.Instance["ModelLoadingDetail"],
        ModelLoadState.Ready => Loc.Instance["ModelReadyDetail"],
        _ => _controller.ModelError ?? Loc.Instance["PhaseModelLoadFailed"]
    };

    public bool IsDownloading => _controller.IsDownloading;
    public double DownloadProgress => _controller.DownloadProgress * 100;
    public string? DownloadError => _controller.DownloadError;
    public string DownloadingName => _controller.DownloadingModelId is { } id
        ? ModelCatalog.Find(id)?.Name(Language) ?? ""
        : "";

    public string ModelsOnDiskText
    {
        get
        {
            var bytes = ModelCatalog.All.Sum(m => AppPaths.ModelSize(m));
            return bytes <= 0 ? "0 MB" : $"{bytes / (1024.0 * 1024.0):0} MB";
        }
    }

    public string HistoryQuery
    {
        get => _historyQuery;
        set
        {
            if (!Set(ref _historyQuery, value)) return;
            RefreshHistory();
        }
    }

    public int TodayWords => _controller.TodayWords;
    public int TotalWords => _controller.TotalWords;
    public int SavedMinutes => _controller.TotalWords / 40;
    public string? MicError => _controller.MicError;
    public string? HookError => _controller.HookError;
    public bool HasHistory => FilteredHistory.Count > 0;
    public bool HasWords => Dictionary.Count > 0;
    public bool HasSnippets => Snippets.Count > 0;

    public void RefreshLocalized()
    {
        foreach (var model in Models) model.Refresh();
        foreach (var preset in HotkeyPresets) preset.Refresh(Language);
        foreach (var sound in Sounds) sound.Refresh(Language);
        foreach (var theme in Themes) theme.Refresh(Language);

        OnPropertyChanged(null);
    }

    private void OnSettingsChanged()
    {
        _selectedLanguage = Languages.First(l => l.Language == Settings.Language);
        _selectedTheme = Themes.First(t => t.Theme == Settings.Theme);
        _selectedSound = Sounds.First(s => s.Sound == Settings.FeedbackSound);

        RefreshLocalized();
        RefreshModelText();
        OnPropertyChanged(nameof(SelectedLanguage));
        OnPropertyChanged(nameof(SelectedTheme));
        OnPropertyChanged(nameof(SelectedSound));
        OnPropertyChanged(nameof(AutoPaste));
        OnPropertyChanged(nameof(RemoveFillers));
        OnPropertyChanged(nameof(PlayFeedbackSound));
        OnPropertyChanged(nameof(ShowSoundPicker));
        OnPropertyChanged(nameof(LaunchAtLogin));
        OnPropertyChanged(nameof(IsHoldMode));
        OnPropertyChanged(nameof(IsToggleMode));
        OnPropertyChanged(nameof(HotkeyDisplay));
    }

    private void OnModelChanged()
    {
        foreach (var model in Models) model.Refresh();
        RefreshModelText();
    }

    private void OnDownloadChanged()
    {
        foreach (var model in Models) model.Refresh();
        RefreshModelText();
    }

    private void RefreshModelText()
    {
        OnPropertyChanged(nameof(NeedsSetup));
        OnPropertyChanged(nameof(CurrentModelName));
        OnPropertyChanged(nameof(ModelStatusTitle));
        OnPropertyChanged(nameof(ModelStatusDetail));
        OnPropertyChanged(nameof(IsDownloading));
        OnPropertyChanged(nameof(DownloadProgress));
        OnPropertyChanged(nameof(DownloadError));
        OnPropertyChanged(nameof(DownloadingName));
        OnPropertyChanged(nameof(ModelsOnDiskText));
        OnPropertyChanged(nameof(MicError));
        OnPropertyChanged(nameof(HookError));
    }

    private void RefreshHistory()
    {
        FilteredHistory.Clear();
        var query = HistoryQuery.Trim();
        var entries = query.Length == 0
            ? _controller.History
            : _controller.History.Where(e => e.Text.Contains(query, StringComparison.OrdinalIgnoreCase));

        foreach (var entry in entries.Take(200))
            FilteredHistory.Add(entry);

        OnPropertyChanged(nameof(TodayWords));
        OnPropertyChanged(nameof(TotalWords));
        OnPropertyChanged(nameof(SavedMinutes));
        OnPropertyChanged(nameof(HasHistory));
    }

    public async Task ActivateModelAsync(ModelRowViewModel row)
    {
        if (row.IsInstalled)
        {
            _controller.SelectModel(row.Spec);
            return;
        }

        await _controller.DownloadModelAsync(row.Spec);
    }

    public void BeginHotkeyCapture()
    {
        HotkeyError = null;
        IsCapturing = true;
        _controller.Hotkey.BeginCapture(Settings.Hotkey.Mode);
    }

    public void CancelHotkeyCapture()
    {
        IsCapturing = false;
        _controller.Hotkey.CancelCapture();
    }

    private void OnHotkeyCaptured(HotkeyBinding binding)
    {
        IsCapturing = false;
        HotkeyError = null;
        _controller.SetHotkey(binding);
    }

    private void OnHotkeyCaptureCancelled()
    {
        IsCapturing = false;
    }

    public void UseHotkeyPreset(HotkeyBinding binding)
    {
        _controller.SetHotkey(binding);
    }

    public void AddDictionaryEntry()
    {
        var entry = new DictionaryEntry();
        Dictionary.Add(entry);
        Settings.Dictionary.Add(entry);
        _controller.SaveSettings();
        OnPropertyChanged(nameof(HasWords));
    }

    public void RemoveDictionaryEntry(DictionaryEntry entry)
    {
        Dictionary.Remove(entry);
        Settings.Dictionary.Remove(entry);
        _controller.SaveSettings();
        OnPropertyChanged(nameof(HasWords));
    }

    public void AddSnippet()
    {
        var snippet = new Snippet();
        Snippets.Add(snippet);
        Settings.Snippets.Add(snippet);
        _controller.SaveSettings();
        OnPropertyChanged(nameof(HasSnippets));
    }

    public void RemoveSnippet(Snippet snippet)
    {
        Snippets.Remove(snippet);
        Settings.Snippets.Remove(snippet);
        _controller.SaveSettings();
        OnPropertyChanged(nameof(HasSnippets));
    }

    public void SaveWords()
    {
        _controller.SaveSettings();
    }

    public void CopyHistory(HistoryEntry entry)
    {
        try { Clipboard.SetText(entry.Text); } catch { }
    }

    public void DeleteHistory(HistoryEntry entry) => _controller.DeleteHistory(entry);

    public void ClearHistory() => _controller.ClearHistory();

    public void RefreshHistoryFromController() => RefreshHistory();

    public void OpenMicSettings()
    {
        try
        {
            Process.Start(new ProcessStartInfo("ms-settings:privacy-microphone") { UseShellExecute = true });
        }
        catch { }
    }

    public void OpenUrl(string url)
    {
        try
        {
            Process.Start(new ProcessStartInfo(url) { UseShellExecute = true });
        }
        catch { }
    }

    public void ShowSettings() => _controller.ShowSettings();
}

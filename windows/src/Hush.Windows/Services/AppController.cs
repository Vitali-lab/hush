using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Threading;
using Hush.Core;
using Hush.Windows.ViewModels;
using Application = System.Windows.Application;

namespace Hush.Windows.Services;

public enum ModelLoadState
{
    NotInstalled,
    OnDisk,
    Loading,
    Ready,
    Error
}

public sealed class AppController : ObservableObject
{
    private readonly SettingsStore _settingsStore;
    private readonly HistoryStore _historyStore;
    private readonly DispatcherTimer _durationTimer;
    private readonly DispatcherTimer _idleTimer;
    private readonly float[] _levels = new float[24];
    private readonly ModelDownloader _downloader;

    private PillWindow? _pill;
    private SettingsWindow? _settingsWindow;
    private TrayService? _tray;
    private DateTime _recordingStarted;
    private DateTime _lastActivity = DateTime.Now;
    private int _idleGeneration;
    private bool _finishing;
    private string? _modelError;
    private string? _micError;
    private string? _hookError;
    private DictationPhase _phase = DictationPhase.Idle;
    private ModelLoadState _modelState = ModelLoadState.NotInstalled;
    private bool _isDownloading;
    private string? _downloadingModelId;
    private double _downloadProgress;
    private string? _downloadError;
    private string _lastResult = "";

    public AppController()
    {
        AppPaths.Ensure();

        _settingsStore = new SettingsStore(AppPaths.SettingsFile);
        _historyStore = new HistoryStore(AppPaths.HistoryFile);
        Settings = _settingsStore.Load();
        History = _historyStore.Load();

        Loc.Instance.Language = Settings.Language;

        Theme = new ThemeManager();
        try { Theme.Apply(Settings.Theme); } catch { }

        _downloader = new ModelDownloader();
        Transcriber = new Transcriber();
        Recorder = new AudioRecorder();
        Sounds = new FeedbackSoundPlayer();
        Hotkey = new HotkeyManager { Binding = Settings.Hotkey };

        Hotkey.Pressed += BeginDictation;
        Hotkey.Released += FinishDictation;
        Hotkey.ToggleRequested += ToggleDictation;
        Hotkey.CancelRequested += CancelDictation;
        Hotkey.HookFailed += message =>
        {
            HookError = message;
            SettingsChanged?.Invoke();
            _tray?.ShowError(message);
        };

        Recorder.LevelChanged += OnLevel;

        _durationTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(100) };
        _durationTimer.Tick += (_, _) =>
        {
            if (Phase != DictationPhase.Listening) return;
            if ((DateTime.UtcNow - _recordingStarted).TotalSeconds >= Math.Max(5, Settings.MaxSeconds))
                FinishDictation();
        };

        _idleTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(30) };
        _idleTimer.Tick += (_, _) =>
        {
            if (Phase != DictationPhase.Idle) return;
            if (Transcriber.LoadedModelPath == null) return;
            if (DateTime.Now - _lastActivity < TimeSpan.FromMinutes(8)) return;

            Transcriber.Unload();
            SetModelState(ModelLoadState.OnDisk);
        };

        SettingsVm = new SettingsViewModel(this);
        RefreshModelState();
    }

    public AppSettings Settings { get; }
    public SettingsViewModel SettingsVm { get; }
    public List<HistoryEntry> History { get; }
    public ThemeManager Theme { get; }
    public HotkeyManager Hotkey { get; }
    public Transcriber Transcriber { get; }
    public AudioRecorder Recorder { get; }
    public FeedbackSoundPlayer Sounds { get; }
    public string Version => AppInfo.Version;

    public event Action? SettingsChanged;
    public event Action? ModelChanged;
    public event Action? DownloadChanged;
    public event Action? HistoryChanged;
    public event Action? PhaseChanged;

    public ModelSpec CurrentModel => ModelCatalog.Find(Settings.ModelId) ?? ModelCatalog.Default;

    public DictationPhase Phase
    {
        get => _phase;
        private set
        {
            if (_phase == value) return;
            _phase = value;
            PhaseChanged?.Invoke();
            OnPropertyChanged();
        }
    }

    public ModelLoadState ModelState
    {
        get => _modelState;
        private set
        {
            if (_modelState == value) return;
            _modelState = value;
            OnPropertyChanged();
            ModelChanged?.Invoke();
        }
    }

    public bool IsDownloading
    {
        get => _isDownloading;
        private set { _isDownloading = value; OnPropertyChanged(); }
    }

    public string? DownloadingModelId
    {
        get => _downloadingModelId;
        private set { _downloadingModelId = value; OnPropertyChanged(); }
    }

    public double DownloadProgress
    {
        get => _downloadProgress;
        private set { _downloadProgress = value; OnPropertyChanged(); }
    }

    public string? DownloadError
    {
        get => _downloadError;
        private set { _downloadError = value; OnPropertyChanged(); }
    }

    public string? ModelError
    {
        get => _modelError;
        private set { _modelError = value; OnPropertyChanged(); }
    }

    public string? MicError
    {
        get => _micError;
        private set { _micError = value; OnPropertyChanged(); }
    }

    public string? HookError
    {
        get => _hookError;
        private set { _hookError = value; OnPropertyChanged(); }
    }

    public string LastResult
    {
        get => _lastResult;
        private set { _lastResult = value; OnPropertyChanged(); }
    }

    public string? LastError { get; private set; }

    public bool IsModelInstalled(ModelSpec model) => AppPaths.IsModelInstalled(model);

    public int TotalWords => History.Sum(e => e.Text.Split(' ', StringSplitOptions.RemoveEmptyEntries).Length);
    public int TodayWords => History
        .Where(e => e.Date.LocalDateTime.Date == DateTime.Today)
        .Sum(e => e.Text.Split(' ', StringSplitOptions.RemoveEmptyEntries).Length);

    public void Start()
    {
        Hotkey.Start();
        Autostart.Set(Settings.LaunchAtLogin);
        _idleTimer.Start();
        RefreshModelState();

        if (AppPaths.IsModelInstalled(CurrentModel))
        {
            if (!Settings.HasCompletedSetup)
            {
                Settings.HasCompletedSetup = true;
                _settingsStore.Save(Settings);
            }

            _ = WarmModelAsync();
        }
    }

    public void Attach(PillWindow pill, SettingsWindow settings)
    {
        _pill = pill;
        _settingsWindow = settings;
        pill.SetPhase(DictationPhase.Idle);
        pill.HidePill();
    }

    public void AttachTray(TrayService tray)
    {
        _tray = tray;
        tray.Refresh(Phase);
    }

    public void ShowSettings() => _settingsWindow?.ShowSettings();

    public void ToggleDictation()
    {
        if (Phase == DictationPhase.Listening)
            FinishDictation();
        else if (Phase is DictationPhase.Idle or DictationPhase.Done or DictationPhase.Copied or DictationPhase.Failed)
            BeginDictation();
    }

    public void BeginDictation()
    {
        if (Phase is DictationPhase.Listening or DictationPhase.Transcribing) return;

        if (!AppPaths.IsModelInstalled(CurrentModel))
        {
            ShowSettings();
            SetPhase(DictationPhase.Failed, Loc.Instance["PhaseModelMissing"]);
            ScheduleIdle(2.2);
            return;
        }

        try
        {
            Recorder.Start();
        }
        catch (Exception ex)
        {
            MicError = ex.Message;
            SettingsChanged?.Invoke();
            SetPhase(DictationPhase.Failed, Loc.Instance["PhaseMicError"]);
            ScheduleIdle(2.2);
            return;
        }

        MicError = null;
        _recordingStarted = DateTime.UtcNow;
        _lastActivity = DateTime.Now;
        _finishing = false;
        Array.Clear(_levels);
        _pill?.SetLevels(_levels);
        CancelPendingIdle();
        SetPhase(DictationPhase.Listening);
        PlayFeedback(starting: true);
        _durationTimer.Start();
        _ = WarmModelAsync();
    }

    public void FinishDictation()
    {
        if (Phase != DictationPhase.Listening) return;

        _durationTimer.Stop();
        var wav = Recorder.Stop();
        var duration = (DateTime.UtcNow - _recordingStarted).TotalSeconds;
        _lastActivity = DateTime.Now;

        if (wav.Length <= 44 + 6_400)
        {
            SetPhase(DictationPhase.Failed, Loc.Instance["PhaseTooShort"]);
            ScheduleIdle(1.2);
            return;
        }

        SetPhase(DictationPhase.Transcribing);
        PlayFeedback(starting: false);
        _ = FinishAsync(wav, duration);
    }

    public void CancelDictation()
    {
        if (Phase != DictationPhase.Listening) return;

        _durationTimer.Stop();
        Recorder.Stop();
        _lastActivity = DateTime.Now;
        SetPhase(DictationPhase.Idle);
        _pill?.HidePill();
    }

    private async Task FinishAsync(byte[] wav, double duration)
    {
        if (_finishing) return;
        _finishing = true;

        try
        {
            var model = CurrentModel;
            var raw = await Transcriber.TranscribeAsync(wav, Settings.Language, model);
            SetModelState(ModelLoadState.Ready);

            var text = TextProcessor.Process(raw, Settings);
            if (string.IsNullOrWhiteSpace(text))
            {
                SetPhase(DictationPhase.Failed, Loc.Instance["PhaseNoSpeech"]);
                ScheduleIdle(1.6);
                return;
            }

            var appName = GetForegroundProcessName();
            var pasted = await TextInserter.InsertAsync(text, Settings.AutoPaste);
            LastResult = text;

            AddHistory(new HistoryEntry
            {
                Text = text,
                AppName = appName,
                Duration = duration,
                Model = model.Id
            });

            SetPhase(pasted ? DictationPhase.Done : DictationPhase.Copied);
            ScheduleIdle(pasted ? 1.6 : 2.6);
        }
        catch (ModelMissingException)
        {
            SetPhase(DictationPhase.Failed, Loc.Instance["ModelFileMissing"]);
            ScheduleIdle(2.4);
        }
        catch (OperationCanceledException)
        {
        }
        catch (Exception ex)
        {
            ModelError = ex.Message;
            SetPhase(DictationPhase.Failed, Loc.Instance["PhaseTranscriptionFailed"]);
            ScheduleIdle(2.4);
        }
        finally
        {
            _finishing = false;
        }
    }

    private void SetPhase(DictationPhase phase, string? error = null)
    {
        Phase = phase;
        LastError = error;

        if (phase == DictationPhase.Idle)
        {
            _pill?.HidePill();
        }
        else
        {
            _pill?.SetPhase(phase);
            _pill?.ShowPill();
        }

        _tray?.Refresh(phase);
    }

    private void ScheduleIdle(double seconds)
    {
        var generation = ++_idleGeneration;
        _ = Task.Delay(TimeSpan.FromSeconds(seconds)).ContinueWith(_ =>
        {
            Application.Current?.Dispatcher.BeginInvoke(new Action(() =>
            {
                if (generation != _idleGeneration) return;
                if (Phase is DictationPhase.Done or DictationPhase.Copied or DictationPhase.Failed)
                    SetPhase(DictationPhase.Idle);
            }));
        });
    }

    private void CancelPendingIdle() => _idleGeneration++;

    private void PlayFeedback(bool starting)
    {
        if (!Settings.PlayFeedbackSound) return;
        Sounds.Play(starting ? Settings.FeedbackSound : FeedbackSound.Tick);
    }

    private void OnLevel(float level)
    {
        Application.Current?.Dispatcher.BeginInvoke(new Action(() =>
        {
            if (Phase != DictationPhase.Listening) return;

            Array.Copy(_levels, 1, _levels, 0, _levels.Length - 1);
            _levels[^1] = level;
            _pill?.SetLevels(_levels);
        }));
    }

    private async Task WarmModelAsync()
    {
        var model = CurrentModel;
        if (!AppPaths.IsModelInstalled(model))
        {
            SetModelState(ModelLoadState.NotInstalled);
            return;
        }

        if (Transcriber.LoadedModelPath == AppPaths.ModelPath(model))
        {
            SetModelState(ModelLoadState.Ready);
            return;
        }

        if (ModelState == ModelLoadState.Loading) return;

        SetModelState(ModelLoadState.Loading);
        try
        {
            await Transcriber.PreloadAsync(model);
            _lastActivity = DateTime.Now;
            SetModelState(ModelLoadState.Ready);
        }
        catch (Exception ex)
        {
            ModelError = ex.Message;
            SetModelState(ModelLoadState.Error);
        }
    }

    private void SetModelState(ModelLoadState state) => ModelState = state;

    public void RefreshModelState()
    {
        if (ModelState == ModelLoadState.Loading) return;

        if (!AppPaths.IsModelInstalled(CurrentModel))
            SetModelState(ModelLoadState.NotInstalled);
        else if (Transcriber.LoadedModelPath == AppPaths.ModelPath(CurrentModel))
            SetModelState(ModelLoadState.Ready);
        else
            SetModelState(ModelLoadState.OnDisk);
    }

    public async Task DownloadModelAsync(ModelSpec model)
    {
        if (IsDownloading || Phase is DictationPhase.Listening or DictationPhase.Transcribing) return;

        IsDownloading = true;
        DownloadingModelId = model.Id;
        DownloadProgress = 0;
        DownloadError = null;
        DownloadChanged?.Invoke();

        try
        {
            var progress = new Progress<DownloadProgress>(p =>
            {
                DownloadProgress = p.Fraction;
                DownloadChanged?.Invoke();
            });

            await _downloader.DownloadAsync(model, progress, CancellationToken.None);

            Settings.ModelId = model.Id;
            Settings.HasCompletedSetup = true;
            SaveSettings();
            RefreshModelState();
            _ = WarmModelAsync();
        }
        catch (Exception ex)
        {
            DownloadError = ex.Message;
        }
        finally
        {
            IsDownloading = false;
            DownloadingModelId = null;
            DownloadChanged?.Invoke();
        }
    }

    public void SelectModel(ModelSpec model)
    {
        if (Settings.ModelId == model.Id) return;
        if (Phase is DictationPhase.Listening or DictationPhase.Transcribing) return;

        Settings.ModelId = model.Id;
        SaveSettings();
        Transcriber.Unload();
        RefreshModelState();

        if (AppPaths.IsModelInstalled(model))
            _ = WarmModelAsync();
    }

    public void SetLanguage(AppLanguage language)
    {
        if (Settings.Language == language) return;
        Settings.Language = language;
        Loc.Instance.Language = language;
        SaveSettings();
    }

    public void SetTheme(AppTheme theme)
    {
        if (Settings.Theme == theme)
        {
            try { Theme.Apply(theme); } catch { }
            return;
        }

        Settings.Theme = theme;
        try { Theme.Apply(theme); } catch { }
        SaveSettings();
    }

    public void SetSound(FeedbackSound sound)
    {
        if (Settings.FeedbackSound == sound) return;
        Settings.FeedbackSound = sound;
        SaveSettings();
    }

    public void PreviewSound(FeedbackSound sound) => Sounds.Play(sound);

    public void SetLaunchAtLogin(bool enabled)
    {
        if (Settings.LaunchAtLogin == enabled) return;
        Settings.LaunchAtLogin = enabled;
        Autostart.Set(enabled);
        SaveSettings();
    }

    public void SetHotkey(HotkeyBinding binding)
    {
        Settings.Hotkey = binding;
        Hotkey.Binding = binding;
        SaveSettings();
    }

    public void SetHotkeyMode(HotkeyMode mode)
    {
        var binding = Settings.Hotkey with { Mode = mode };
        SetHotkey(binding);
    }

    public void SaveSettings()
    {
        _settingsStore.Save(Settings);
        SettingsChanged?.Invoke();
    }

    public void AddHistory(HistoryEntry entry)
    {
        History.Insert(0, entry);
        if (History.Count > 500)
            History.RemoveRange(500, History.Count - 500);
        _historyStore.Save(History);
        HistoryChanged?.Invoke();
        OnPropertyChanged(nameof(TotalWords));
        OnPropertyChanged(nameof(TodayWords));
    }

    public void DeleteHistory(HistoryEntry entry)
    {
        History.RemoveAll(e => e.Id == entry.Id);
        _historyStore.Save(History);
        HistoryChanged?.Invoke();
        OnPropertyChanged(nameof(TotalWords));
        OnPropertyChanged(nameof(TodayWords));
    }

    public void ClearHistory()
    {
        History.Clear();
        _historyStore.Save(History);
        HistoryChanged?.Invoke();
        OnPropertyChanged(nameof(TotalWords));
        OnPropertyChanged(nameof(TodayWords));
    }

    public void Quit()
    {
        SaveSettings();
        _settingsWindow?.AllowClose();
        _durationTimer.Stop();
        _idleTimer.Stop();
        Hotkey.Dispose();
        Transcriber.Dispose();
        Recorder.Dispose();
        _tray?.Dispose();
        Application.Current?.Shutdown();
    }

    private static string? GetForegroundProcessName()
    {
        try
        {
            var hwnd = GetForegroundWindow();
            if (hwnd == IntPtr.Zero) return null;
            GetWindowThreadProcessId(hwnd, out var pid);
            using var process = Process.GetProcessById((int)pid);
            return process.ProcessName;
        }
        catch
        {
            return null;
        }
    }

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
}

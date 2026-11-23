using System.ComponentModel;
using System.Windows.Media;
using Brush = System.Windows.Media.Brush;
using Brushes = System.Windows.Media.Brushes;
using Color = System.Windows.Media.Color;
using ColorConverter = System.Windows.Media.ColorConverter;
using LinearGradientBrush = System.Windows.Media.LinearGradientBrush;
using Hush.Core;
using Hush.Windows.Services;

namespace Hush.Windows.ViewModels;

public abstract class ObservableObject : INotifyPropertyChanged
{
    public event PropertyChangedEventHandler? PropertyChanged;

    protected void OnPropertyChanged(string? name = null) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));

    protected bool Set<T>(ref T field, T value, string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value)) return false;
        field = value;
        OnPropertyChanged(name);
        return true;
    }
}

public sealed class ModelRowViewModel : ObservableObject
{
    private readonly AppController _controller;

    public ModelRowViewModel(AppController controller, ModelSpec spec)
    {
        _controller = controller;
        Spec = spec;
        Refresh();
    }

    public ModelSpec Spec { get; }
    public string Name => Spec.Name(_controller.Settings.Language);
    public string Detail => Spec.Detail(_controller.Settings.Language);
    public string SizeLabel => Spec.SizeLabel;
    public string SpeedText => new string('●', Spec.Speed) + new string('○', 5 - Spec.Speed);
    public string AccuracyText => new string('●', Spec.Accuracy) + new string('○', 5 - Spec.Accuracy);
    public bool IsRecommended => Spec.IsRecommended;
    public bool IsInstalled => AppPaths.IsModelInstalled(Spec);
    public bool IsSelected => _controller.Settings.ModelId == Spec.Id;
    public bool IsDownloading => _controller.IsDownloading && _controller.DownloadingModelId == Spec.Id;
    public double Progress => IsDownloading ? _controller.DownloadProgress * 100 : 0;
    public string StatusText =>
        IsDownloading ? $"{Progress:0}%" :
        IsSelected ? Loc.Instance["ModelInUse"] :
        IsInstalled ? Loc.Instance["ModelDownloaded"] :
        Loc.Instance["ModelNotInstalled"];

    public string ActionText =>
        IsDownloading ? $"{Progress:0}%" :
        IsSelected ? Loc.Instance["ModelInUse"] :
        IsInstalled ? Loc.Instance["ModelUse"] :
        $"{Loc.Instance["ModelDownload"]} · {SizeLabel}";

    public bool CanAct => !IsDownloading && !IsSelected;

    public void Refresh()
    {
        OnPropertyChanged(nameof(Name));
        OnPropertyChanged(nameof(Detail));
        OnPropertyChanged(nameof(SizeLabel));
        OnPropertyChanged(nameof(SpeedText));
        OnPropertyChanged(nameof(AccuracyText));
        OnPropertyChanged(nameof(IsRecommended));
        OnPropertyChanged(nameof(IsInstalled));
        OnPropertyChanged(nameof(IsSelected));
        OnPropertyChanged(nameof(IsDownloading));
        OnPropertyChanged(nameof(Progress));
        OnPropertyChanged(nameof(StatusText));
        OnPropertyChanged(nameof(ActionText));
        OnPropertyChanged(nameof(CanAct));
    }
}

public sealed class ThemeOption : ObservableObject
{
    public ThemeOption(AppTheme theme, AppLanguage language)
    {
        Theme = theme;
        Refresh(language);
    }

    public AppTheme Theme { get; }
    public string Name { get; private set; } = "";
    public Brush Swatch { get; private set; } = Brushes.Gray;
    public bool IsDark { get; private set; }

    public void Refresh(AppLanguage language)
    {
        Name = L10n.ThemeName(Theme, language);
        IsDark = Theme is AppTheme.Graphite or AppTheme.Midnight or AppTheme.System;

        var colors = Theme switch
        {
            AppTheme.Daylight => ("#6C9BFF", "#FF6B9C"),
            AppTheme.Sand => ("#E0A46B", "#D96C7B"),
            AppTheme.Graphite => ("#9FB4FF", "#C86DD7"),
            AppTheme.Midnight => ("#A78BFA", "#F472B6"),
            _ => ("#A78BFA", "#F472B6")
        };

        Swatch = new LinearGradientBrush(
            (Color)ColorConverter.ConvertFromString(colors.Item1),
            (Color)ColorConverter.ConvertFromString(colors.Item2),
            new System.Windows.Point(0, 0),
            new System.Windows.Point(1, 1));

        OnPropertyChanged(nameof(Name));
        OnPropertyChanged(nameof(Swatch));
        OnPropertyChanged(nameof(IsDark));
    }
}

public sealed class SoundOption : ObservableObject
{
    public SoundOption(FeedbackSound sound, AppLanguage language)
    {
        Sound = sound;
        Refresh(language);
    }

    public FeedbackSound Sound { get; }
    public string Name { get; private set; } = "";
    public string Detail { get; private set; } = "";

    public void Refresh(AppLanguage language)
    {
        Name = L10n.SoundName(Sound, language);
        Detail = L10n.SoundDetail(Sound, language);
        OnPropertyChanged(nameof(Name));
        OnPropertyChanged(nameof(Detail));
    }
}

public sealed class HotkeyPresetOption : ObservableObject
{
    public HotkeyPresetOption(HotkeyBinding binding, AppLanguage language)
    {
        Binding = binding;
        Language = language;
        Refresh(language);
    }

    public HotkeyBinding Binding { get; }
    private AppLanguage Language { get; set; }
    public string Display { get; private set; } = "";

    public void Refresh(AppLanguage language)
    {
        Language = language;
        Display = Binding.Display(language);
        OnPropertyChanged(nameof(Display));
    }
}

public sealed class LanguageOption
{
    public LanguageOption(AppLanguage language) => Language = language;

    public AppLanguage Language { get; }
    public string Name => L10n.LanguageName(Language);
}

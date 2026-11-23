using System.Windows;
using Application = System.Windows.Application;

using Hush.Core;
using Microsoft.Win32;

namespace Hush.Windows.Services;

public sealed class ThemeManager
{
    private const string ThemePath = "Resources/Themes";

    public AppTheme Current { get; private set; } = AppTheme.System;
    public bool IsDark { get; private set; }

    public void Apply(AppTheme theme)
    {
        var effective = theme == AppTheme.System
            ? (SystemUsesLight() ? AppTheme.Daylight : AppTheme.Graphite)
            : theme;

        var app = Application.Current;
        if (app == null) return;

        var source = new Uri($"pack://application:,,,/Hush;component/{ThemePath}/{effective}.xaml", UriKind.Absolute);
        if (app.Resources.MergedDictionaries.FirstOrDefault(d => d.Source == source) == null)
        {
            var dictionary = new ResourceDictionary { Source = source };
            var existing = app.Resources.MergedDictionaries
                .Select((d, i) => (Dictionary: d, Index: i))
                .FirstOrDefault(x => x.Dictionary.Source?.OriginalString.Contains("/Themes/") == true);

            if (existing.Dictionary != null)
            {
                app.Resources.MergedDictionaries.RemoveAt(existing.Index);
                app.Resources.MergedDictionaries.Insert(existing.Index, dictionary);
            }
            else
            {
                app.Resources.MergedDictionaries.Insert(0, dictionary);
            }
        }

        Current = theme;
        IsDark = effective is AppTheme.Graphite or AppTheme.Midnight;
    }

    public static bool SystemUsesLight()
    {
        try
        {
            var value = Registry.GetValue(
                @"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize",
                "AppsUseLightTheme",
                1);
            return Convert.ToInt32(value) != 0;
        }
        catch
        {
            return true;
        }
    }
}

using System.Windows;
using System.Windows.Threading;
using Hush.Windows.Services;
using NAudio.MediaFoundation;

namespace Hush.Windows;

public partial class App : System.Windows.Application
{
    private Mutex? _singleInstance;
    private AppController? _controller;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        _singleInstance = new Mutex(true, "Hush.Windows.SingleInstance", out var created);
        if (!created)
        {
            System.Windows.MessageBox.Show("Hush is already running.", "Hush",
                MessageBoxButton.OK, MessageBoxImage.Information);
            Shutdown();
            return;
        }

        DispatcherUnhandledException += OnUnhandledException;

        try
        {
            MediaFoundationApi.Startup();
        }
        catch
        {
            // Audio capture reports its own error if Media Foundation is unavailable.
        }

        _controller = new AppController();
        var pill = new PillWindow();
        var settings = new SettingsWindow(_controller);
        _controller.Attach(pill, settings);
        _controller.AttachTray(new TrayService(_controller));
        _controller.Start();

        var minimized = e.Args.Contains("--minimized");
        var needsSetup = !_controller.IsModelInstalled(_controller.CurrentModel) ||
                         !_controller.Settings.HasCompletedSetup;

        if (!minimized || needsSetup)
            settings.ShowSettings();
    }

    private void OnUnhandledException(object sender, DispatcherUnhandledExceptionEventArgs e)
    {
        try
        {
            AppPaths.Ensure();
            File.AppendAllText(
                Path.Combine(AppPaths.Root, "hush.log"),
                $"[{DateTime.Now:u}] {e.Exception}\n");
        }
        catch { }

        System.Windows.MessageBox.Show(
            e.Exception.Message,
            "Hush error",
            MessageBoxButton.OK,
            MessageBoxImage.Error);

        e.Handled = true;
    }

    protected override void OnExit(ExitEventArgs e)
    {
        try { MediaFoundationApi.Shutdown(); } catch { }
        _singleInstance?.Dispose();
        base.OnExit(e);
    }
}

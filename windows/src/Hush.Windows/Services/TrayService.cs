using System.Drawing;
using System.Windows.Forms;

namespace Hush.Windows.Services;

public sealed class TrayService : IDisposable
{
    private readonly AppController _controller;
    private readonly NotifyIcon _icon;
    private readonly ContextMenuStrip _menu;
    private readonly ToolStripMenuItem _toggle;
    private readonly ToolStripMenuItem _settings;
    private readonly ToolStripMenuItem _quit;

    public TrayService(AppController controller)
    {
        _controller = controller;

        _toggle = new ToolStripMenuItem(Loc.Instance["TrayStart"], null, (_, _) => _controller.ToggleDictation());
        _settings = new ToolStripMenuItem(Loc.Instance["TraySettings"], null, (_, _) => _controller.ShowSettings());
        _quit = new ToolStripMenuItem(Loc.Instance["TrayQuit"], null, (_, _) => _controller.Quit());

        _menu = new ContextMenuStrip();
        _menu.Items.Add(_toggle);
        _menu.Items.Add(_settings);
        _menu.Items.Add(new ToolStripSeparator());
        _menu.Items.Add(_quit);

        _icon = new NotifyIcon
        {
            Icon = LoadIcon(),
            Text = Loc.Instance["TrayTip"],
            Visible = true,
            ContextMenuStrip = _menu
        };

        _icon.DoubleClick += (_, _) => _controller.ShowSettings();
        _controller.SettingsChanged += UpdateText;
        _controller.PhaseChanged += () => Refresh(_controller.Phase);
    }

    public void Refresh(DictationPhase phase)
    {
        _toggle.Text = phase == DictationPhase.Listening
            ? Loc.Instance["TrayStop"]
            : Loc.Instance["TrayStart"];
        _toggle.Enabled = phase != DictationPhase.Transcribing;
        _icon.Text = Loc.Instance["TrayTip"];
    }

    public void ShowError(string message)
    {
        try
        {
            _icon.BalloonTipTitle = "Hush";
            _icon.BalloonTipText = message;
            _icon.ShowBalloonTip(3000);
        }
        catch
        {
            // Balloons are optional.
        }
    }

    private void UpdateText()
    {
        _toggle.Text = _controller.Phase == DictationPhase.Listening
            ? Loc.Instance["TrayStop"]
            : Loc.Instance["TrayStart"];
        _settings.Text = Loc.Instance["TraySettings"];
        _quit.Text = Loc.Instance["TrayQuit"];
        _icon.Text = Loc.Instance["TrayTip"];
        _menu.Refresh();
    }

    private static Icon LoadIcon()
    {
        try
        {
            var path = Path.Combine(AppContext.BaseDirectory, "Assets", "hush.ico");
            if (File.Exists(path)) return new Icon(path);
        }
        catch { }

        return SystemIcons.Application;
    }

    public void Dispose()
    {
        _icon.Visible = false;
        _icon.Dispose();
        _menu.Dispose();
    }
}

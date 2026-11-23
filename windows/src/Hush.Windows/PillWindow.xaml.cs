using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Threading;
using Hush.Windows.Services;

namespace Hush.Windows;

public partial class PillWindow : Window
{
    private const int GWL_EXSTYLE = -20;
    private const int WS_EX_TRANSPARENT = 0x00000020;
    private const int WS_EX_TOOLWINDOW = 0x00000080;
    private const int WS_EX_NOACTIVATE = 0x08000000;

    private readonly DispatcherTimer _dotsTimer;
    private int _dotPhase;

    public PillWindow()
    {
        InitializeComponent();

        _dotsTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(240) };
        _dotsTimer.Tick += (_, _) =>
        {
            _dotPhase = (_dotPhase + 1) % 3;
            var ellipses = Dots.Children.OfType<System.Windows.Shapes.Ellipse>().ToArray();
            for (var i = 0; i < ellipses.Length; i++)
            {
                ellipses[i].Opacity = i == _dotPhase ? 1 : 0.25;
                ellipses[i].LayoutTransform = i == _dotPhase
                    ? new ScaleTransform(1.15, 1.15)
                    : Transform.Identity;
            }
        };

        SourceInitialized += OnSourceInitialized;
    }

    private void OnSourceInitialized(object? sender, EventArgs e)
    {
        var handle = new WindowInteropHelper(this).Handle;
        var extended = GetWindowLong(handle, GWL_EXSTYLE);
        SetWindowLong(handle, GWL_EXSTYLE,
            extended | WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE);
    }

    public void SetLevels(float[] levels)
    {
        Waveform.Levels = levels;
    }

    public void SetPhase(DictationPhase phase)
    {
        Waveform.Visibility = Visibility.Collapsed;
        Dots.Visibility = Visibility.Collapsed;
        StatusIcon.Visibility = Visibility.Collapsed;

        switch (phase)
        {
            case DictationPhase.Listening:
                Waveform.Visibility = Visibility.Visible;
                break;
            case DictationPhase.Transcribing:
                Dots.Visibility = Visibility.Visible;
                _dotPhase = 0;
                _dotsTimer.Start();
                break;
            case DictationPhase.Done:
                _dotsTimer.Stop();
                StatusIcon.Text = "\uE73E";
                StatusIcon.Visibility = Visibility.Visible;
                break;
            case DictationPhase.Copied:
                _dotsTimer.Stop();
                StatusIcon.Text = "\uE8C8";
                StatusIcon.Visibility = Visibility.Visible;
                break;
            case DictationPhase.Failed:
                _dotsTimer.Stop();
                StatusIcon.Text = "\uE7BA";
                StatusIcon.Visibility = Visibility.Visible;
                break;
            default:
                _dotsTimer.Stop();
                break;
        }
    }

    public void ShowPill()
    {
        var area = SystemParameters.WorkArea;
        Left = area.Left + (area.Width - Width) / 2;
        Top = area.Bottom - Height - 34;
        Show();
    }

    public void HidePill()
    {
        _dotsTimer.Stop();
        Hide();
    }

    [DllImport("user32.dll")]
    private static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll")]
    private static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
}

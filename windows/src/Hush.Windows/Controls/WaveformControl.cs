using System.Windows;
using System.Windows.Media;
using Brush = System.Windows.Media.Brush;
using Brushes = System.Windows.Media.Brushes;

namespace Hush.Windows.Controls;

public sealed class WaveformControl : FrameworkElement
{
    public static readonly DependencyProperty BarBrushProperty = DependencyProperty.Register(
        nameof(BarBrush), typeof(Brush), typeof(WaveformControl),
        new FrameworkPropertyMetadata(Brushes.White, FrameworkPropertyMetadataOptions.AffectsRender));

    private float[] _levels = new float[24];

    public Brush BarBrush
    {
        get => (Brush)GetValue(BarBrushProperty);
        set => SetValue(BarBrushProperty, value);
    }

    public float[] Levels
    {
        get => _levels;
        set
        {
            _levels = value ?? [];
            InvalidateVisual();
        }
    }

    protected override void OnRender(DrawingContext drawingContext)
    {
        base.OnRender(drawingContext);

        const int bars = 24;
        const double barWidth = 1.8;
        const double gap = 1.9;
        var totalWidth = bars * barWidth + (bars - 1) * gap;
        var startX = (ActualWidth - totalWidth) / 2;
        var centerY = ActualHeight / 2;

        var brush = BarBrush;
        for (var i = 0; i < bars; i++)
        {
            var level = i < _levels.Length ? Math.Clamp(_levels[i], 0, 1) : 0;
            var height = Math.Max(2, level * 17);
            var rect = new Rect(
                startX + i * (barWidth + gap),
                centerY - height / 2,
                barWidth,
                height);
            drawingContext.DrawRoundedRectangle(brush, null, rect, barWidth / 2, barWidth / 2);
        }
    }
}

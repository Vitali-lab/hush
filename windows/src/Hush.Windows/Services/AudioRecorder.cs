using NAudio.CoreAudioApi;
using NAudio.MediaFoundation;
using NAudio.Wave;

namespace Hush.Windows.Services;

public sealed class MicrophoneException : Exception
{
    public MicrophoneException(string message, Exception? inner = null) : base(message, inner) { }
}

public sealed class AudioRecorder : IDisposable
{
    private readonly object _sync = new();
    private readonly List<short> _samples = [];
    private WasapiCapture? _capture;
    private BufferedWaveProvider? _buffer;
    private MediaFoundationResampler? _resampler;
    private bool _recording;

    public event Action<float>? LevelChanged;

    public bool IsRecording
    {
        get { lock (_sync) return _recording; }
    }

    public double Seconds
    {
        get { lock (_sync) return _samples.Count / 16_000.0; }
    }

    public void Start()
    {
        lock (_sync)
        {
            if (_recording) return;
            _samples.Clear();
        }

        try
        {
            _capture = new WasapiCapture();
            _buffer = new BufferedWaveProvider(_capture.WaveFormat)
            {
                BufferDuration = TimeSpan.FromSeconds(3),
                DiscardOnBufferOverflow = true
            };
            _resampler = new MediaFoundationResampler(_buffer, new WaveFormat(16_000, 16, 1))
            {
                ResamplerQuality = 60
            };

            _capture.DataAvailable += OnDataAvailable;
            _capture.StartRecording();

            lock (_sync)
            {
                _recording = true;
            }
        }
        catch (Exception ex)
        {
            DisposeCapture();
            throw new MicrophoneException(ex.Message, ex);
        }
    }

    public byte[] Stop()
    {
        lock (_sync)
        {
            if (!_recording) return [];
            _recording = false;
        }

        try { _capture?.StopRecording(); } catch { }

        lock (_sync)
        {
            DrainResampler();
            var samples = _samples.ToArray();
            DisposeCapture();
            return BuildWav(samples);
        }
    }

    private void OnDataAvailable(object? sender, WaveInEventArgs e)
    {
        if (!_recording || e.BytesRecorded == 0) return;

        try
        {
            double sum = 0;
            var count = 0;

            lock (_sync)
            {
                if (!_recording || _buffer == null || _resampler == null) return;

                _buffer.AddSamples(e.Buffer, 0, e.BytesRecorded);
                var output = new byte[6_400];
                int read;
                while ((read = _resampler.Read(output, 0, output.Length)) > 0)
                {
                    for (var i = 0; i + 1 < read; i += 2)
                    {
                        var sample = BitConverter.ToInt16(output, i);
                        _samples.Add(sample);
                        sum += (double)sample * sample;
                        count++;
                    }
                }
            }

            if (count == 0)
            {
                LevelChanged?.Invoke(0);
                return;
            }

            var rms = Math.Sqrt(sum / count);
            var decibels = 20 * Math.Log10(Math.Max(rms, 1) / 32_768.0);
            var normalized = Math.Clamp((decibels + 55) / 55, 0, 1);
            LevelChanged?.Invoke((float)normalized);
        }
        catch
        {
            // A device reset can throw from the resampler; stop cleanly.
            LevelChanged?.Invoke(0);
        }
    }

    private void DrainResampler()
    {
        if (_resampler == null) return;

        var output = new byte[6_400];
        int read;
        while ((read = _resampler.Read(output, 0, output.Length)) > 0)
        {
            for (var i = 0; i + 1 < read; i += 2)
                _samples.Add(BitConverter.ToInt16(output, i));
        }
    }

    private static byte[] BuildWav(short[] samples)
    {
        using var stream = new MemoryStream();
        using (var writer = new WaveFileWriter(stream, new WaveFormat(16_000, 16, 1)))
        {
            writer.WriteSamples(samples, 0, samples.Length);
        }
        return stream.ToArray();
    }

    private void DisposeCapture()
    {
        if (_capture != null)
        {
            _capture.DataAvailable -= OnDataAvailable;
            try { _capture.Dispose(); } catch { }
            _capture = null;
        }

        _resampler?.Dispose();
        _resampler = null;
        _buffer = null;
    }

    public void Dispose()
    {
        lock (_sync)
        {
            if (_recording)
            {
                _recording = false;
                try { _capture?.StopRecording(); } catch { }
            }
            DisposeCapture();
        }
    }
}

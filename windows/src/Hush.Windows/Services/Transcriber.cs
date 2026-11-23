using System.Text;
using Hush.Core;
using Whisper.net;

namespace Hush.Windows.Services;

public sealed class ModelMissingException : Exception
{
    public ModelMissingException() : base("The speech model is not downloaded.") { }
}

public sealed class Transcriber : IDisposable
{
    private readonly SemaphoreSlim _gate = new(1, 1);
    private readonly object _sync = new();
    private WhisperFactory? _factory;
    private string? _factoryPath;

    public string? LoadedModelPath
    {
        get { lock (_sync) return _factoryPath; }
    }

    public async Task<string> TranscribeAsync(
        byte[] wav,
        AppLanguage language,
        ModelSpec model,
        CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            return await Task.Run(async () =>
            {
                EnsureFactory(model);

                using var processor = _factory!.CreateBuilder()
                    .WithLanguage(language == AppLanguage.Russian ? "ru" : "en")
                    .WithThreads(Math.Clamp(Environment.ProcessorCount / 2, 2, 8))
                    .WithNoContext()
                    .WithNoSpeechThreshold(0.6f)
                    .Build();

                using var stream = new MemoryStream(wav, writable: false);
                var builder = new StringBuilder();

                await foreach (var segment in processor.ProcessAsync(stream).ConfigureAwait(false))
                {
                    cancellationToken.ThrowIfCancellationRequested();
                    builder.Append(segment.Text);
                }

                return builder.ToString().Trim();
            }, cancellationToken).ConfigureAwait(false);
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task PreloadAsync(ModelSpec model)
    {
        await _gate.WaitAsync().ConfigureAwait(false);
        try
        {
            await Task.Run(() => EnsureFactory(model)).ConfigureAwait(false);
        }
        finally
        {
            _gate.Release();
        }
    }

    public void Unload()
    {
        lock (_sync)
        {
            _factory?.Dispose();
            _factory = null;
            _factoryPath = null;
        }
    }

    private void EnsureFactory(ModelSpec model)
    {
        var path = AppPaths.ModelPath(model);
        if (!File.Exists(path)) throw new ModelMissingException();

        lock (_sync)
        {
            if (_factory != null && _factoryPath == path) return;

            _factory?.Dispose();
            _factory = WhisperFactory.FromPath(path);
            _factoryPath = path;
        }
    }

    public void Dispose()
    {
        Unload();
        _gate.Dispose();
    }
}

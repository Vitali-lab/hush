using System.Net.Http;
using Hush.Core;

namespace Hush.Windows.Services;

public sealed record DownloadProgress(double Fraction, long Bytes, long TotalBytes);

public sealed class ModelDownloader
{
    private static readonly HttpClient Client = CreateClient();

    private static HttpClient CreateClient()
    {
        var client = new HttpClient { Timeout = Timeout.InfiniteTimeSpan };
        client.DefaultRequestHeaders.UserAgent.ParseAdd("Hush/1.2.1");
        return client;
    }

    public async Task DownloadAsync(
        ModelSpec model,
        IProgress<DownloadProgress>? progress,
        CancellationToken cancellationToken)
    {
        AppPaths.Ensure();
        var target = AppPaths.ModelPath(model);
        var temp = target + ".part";

        try
        {
            using var response = await Client.GetAsync(
                model.Url,
                HttpCompletionOption.ResponseHeadersRead,
                cancellationToken);
            response.EnsureSuccessStatusCode();

            var total = response.Content.Headers.ContentLength ?? model.SizeMB * 1024L * 1024L;
            await using var input = await response.Content.ReadAsStreamAsync(cancellationToken);
            await using var output = new FileStream(temp, FileMode.Create, FileAccess.Write, FileShare.None, 1 << 20, true);

            var buffer = new byte[1 << 20];
            long received = 0;
            var lastReport = DateTime.UtcNow;

            while (true)
            {
                var read = await input.ReadAsync(buffer, cancellationToken);
                if (read == 0) break;

                await output.WriteAsync(buffer.AsMemory(0, read), cancellationToken);
                received += read;

                if (DateTime.UtcNow - lastReport > TimeSpan.FromMilliseconds(150))
                {
                    lastReport = DateTime.UtcNow;
                    progress?.Report(new DownloadProgress(
                        total > 0 ? Math.Clamp((double)received / total, 0, 1) : 0,
                        received,
                        total));
                }
            }

            await output.FlushAsync(cancellationToken);
            output.Close();
            File.Move(temp, target, true);
            progress?.Report(new DownloadProgress(1, received, total));
        }
        catch
        {
            try { if (File.Exists(temp)) File.Delete(temp); } catch { }
            throw;
        }
    }
}

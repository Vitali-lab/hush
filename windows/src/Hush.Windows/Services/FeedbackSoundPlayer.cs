using System.Media;
using System.Reflection;
using Hush.Core;

namespace Hush.Windows.Services;

public sealed class FeedbackSoundPlayer
{
    private readonly Dictionary<FeedbackSound, SoundPlayer> _players = [];

    public FeedbackSoundPlayer()
    {
        var assembly = Assembly.GetExecutingAssembly();
        var names = assembly.GetManifestResourceNames();

        foreach (var sound in Enum.GetValues<FeedbackSound>())
        {
            var suffix = $".{sound.ToString().ToLowerInvariant()}.wav";
            var name = names.FirstOrDefault(n => n.EndsWith(suffix, StringComparison.OrdinalIgnoreCase));
            if (name == null) continue;

            using var stream = assembly.GetManifestResourceStream(name);
            if (stream == null) continue;

            var memory = new MemoryStream();
            stream.CopyTo(memory);
            memory.Position = 0;
            _players[sound] = new SoundPlayer(memory);
        }
    }

    public void Play(FeedbackSound sound)
    {
        if (!_players.TryGetValue(sound, out var player)) return;

        try
        {
            player.Play();
        }
        catch
        {
            // Audio is a nicety, never a reason to fail a dictation.
        }
    }
}

# Sotto

Local-first dictation for macOS. Hold a key, speak, and the text lands at your
cursor in any app. No account, no cloud, no telemetry.

Sotto is a deliberately small take on Wispr Flow: one shortcut, one floating
pill, one local speech model. Everything else is out of the way.

```
dist/Sotto.app  ·  ~8 MB  ·  macOS 14+  ·  Apple Silicon
```

## What it does

- **Dictate anywhere** — Slack, Mail, Cursor, a terminal, a browser. The text is
  pasted at the focused cursor, so any text field works.
- **Fully offline** — Whisper `large-v3` Turbo converted to CoreML, running on
  the Neural Engine. Audio is recorded in memory and never uploaded.
- **One-time 632 MB model** — the model loads in under two seconds and the
  process stays around 130–200 MB of RAM while transcribing.
- **Russian and English out of the box** — plus 100+ other languages via
  Whisper, with auto-detection.
- **Small quality-of-life bits** — custom words, snippets, filler-word cleanup,
  optional sound feedback, history with search, launch at login.
- **Built to stay quiet** — menu-bar only, no Dock icon, no background daemons.

## Deliberately not here

No meeting recorder, no notes app, no AI agents, no team spaces, no accounts,
no cloud sync, no analytics. Those are fine products; they are not this one.
The model unloads itself after eight quiet minutes, so idle RAM goes back to
a menu-bar app's footprint.

## Install

Requires macOS 14 (Sonoma) or newer and the Xcode Command Line Tools
(`xcode-select --install`). Xcode itself is not required.

```bash
git clone https://github.com/Vitali-lab/sotto.git
cd sotto
./scripts/build_app.sh
open dist/Sotto.app
```

Then drag `dist/Sotto.app` into `/Applications` if you want to keep it around.
The build script signs with the first available `Apple Development` identity,
or ad-hoc if there is none.

> The app is not notarized. If you copy the built `.app` to another Mac,
> either build it there or clear the quarantine flag:
> `xattr -dr com.apple.quarantine /Applications/Sotto.app`.

On first launch Sotto asks for:

1. **Microphone** — to hear you.
2. **Accessibility** — for the global shortcut and for pasting text into other
   apps. macOS may ask you to restart the app afterwards.
3. **A speech model** — downloaded once, then never again.

> If Fn also opens the emoji picker on your Mac, turn off the system dictation
> shortcut (System Settings → Keyboard → Dictation) or pick another shortcut in
> Sotto → Settings → General.

## Use

| Action | Default |
| --- | --- |
| Start / stop dictation | Hold `Fn`, speak, release |
| Cancel while recording | `Esc` |
| Open settings | `⌘ ,` |
| Quit | `⌘ Q` |

Other shortcuts: hold Right `⌥`, double-tap `Fn`, or `⌃⌥Space` to toggle.

After release the text is pasted at the cursor. If Accessibility is missing,
Sotto copies the text to the clipboard instead and says so in the pill.

## Models

| Model | Disk | Speed | Accuracy | Notes |
| --- | --- | --- | --- | --- |
| Large v3 Turbo · Compact | 632 MB | good | best | Default. Compressed turbo weights. |
| Large v3 Turbo | 1.6 GB | good | best | Uncompressed version of the same model. |
| Small | 486 MB | best | okay | Older Macs, clear speech. |
| Base | 148 MB | best | meh | Tiny, noticeably weaker. |

All models are CoreML builds from
[Argmax WhisperKit](https://github.com/argmaxinc/argmax-oss-swift) and run on
the Apple Neural Engine. Model files live in
`~/Library/Application Support/Sotto/Models`.

## Why this model and not something bigger
- **Quality for Russian**: large-v3 Turbo handles Russian punctuation and mixed
  Russian/English well. The 626 MB compressed build keeps nearly all of that
  quality while halving the disk footprint.
- **Resources**: in a local test an 8-second Russian clip loaded the model in
  1.8 s and finished in 2.3 s total, with a 130 MB peak RSS. Typing that text
  would have taken much longer.
- **No Python, no server**: CoreML runs inside the app. Nothing to boot, no port
  to babysit, no GPU fan noise. The model unloads after eight idle minutes.
- **Alternatives**: Parakeet TDT v3 is faster but weaker on Russian endings;
  Qwen3-ASR is more accurate but needs an MLX/Python runtime and more memory.
  Turbo is the sweet spot for a native macOS app.

## How it works

```
Fn down ─▶ AVAudioEngine (16 kHz mono) ─▶ WhisperKit / CoreML ─▶ cleanup
       ─▶ clipboard + ⌘V at cursor ─▶ restore clipboard
```

- `Audio/HotkeyManager` — global shortcut via `NSEvent` monitors.
- `Audio/AudioRecorder.swift` — mic tap and resampling to 16 kHz.
- `Speech/TranscriptionService.swift` — lazy model load, decoding options.
- `Text/TextProcessor.swift` — fillers, dictionary, snippets, spacing.
- `System/TextInserter.swift` — paste with clipboard restore.
- `UI/HUD` — non-activating floating pill with a live waveform.
- `UI/Settings` — five small tabs, no wizards.

Settings are stored in `~/Library/Application Support/Sotto/settings.json`,
history in `history.json`, models under `Models/`.

## Development

```bash
swift build                    # debug binary
swift run Sotto                # run from the terminal
./scripts/build_app.sh         # signed .app in dist/
./scripts/make_icon.sh         # regenerate the icon
```

Hidden helpers used for screenshots and model checks:

```bash
.build/debug/Sotto --transcribe path/to/audio.wav   # prints transcription
.build/debug/Sotto --render-ui /tmp/previews        # renders SwiftUI previews
.build/debug/Sotto --capture-ui /tmp/shots          # captures real windows
```

## Privacy

Sotto has no networking code except the one-time model download from
Hugging Face. Audio is kept in memory, transcribed on-device, and discarded
after the text is produced. Nothing is logged to disk unless you keep history,
which stays in your Application Support folder.

## Credits

- [WhisperKit](https://github.com/argmaxinc/argmax-oss-swift) by Argmax — MIT
- [Whisper](https://github.com/openai/whisper) by OpenAI — MIT
- Inspired by [Wispr Flow](https://wisprflow.ai) and the open-source
  [OpenWhispr](https://github.com/OpenWhispr/openwhispr) — MIT

Sotto itself is MIT licensed. See [LICENSE](LICENSE).

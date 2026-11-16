# Hush

**Speak softly. We'll do the typing.**

Local-first dictation for macOS. Hold a key, say what you mean, release — the
text lands at your cursor in any app. No account, no cloud, no telemetry.

[Русская версия →](README.ru.md)

```
Hush.app · ~8 MB · macOS 14+ · Apple Silicon (Intel builds from source)
```

## What it does

- **Dictate anywhere** — Slack, Mail, Cursor, Terminal, a browser. The text is
  pasted at the focused cursor, so any text field works.
- **Two languages, one switch** — English or Russian for both the interface and
  recognition. RU listens only in Russian, EN only in English. No auto-guessing.
- **Any shortcut you want** — hold Fn, hold Right Option, press a key combo, or
  record your own key in Settings.
- **Fully offline** — Whisper `large-v3` Turbo converted to CoreML, running on
  the Neural Engine. Audio is recorded in memory and never uploaded.
- **Light on resources** — ~130–200 MB RAM while transcribing, model loads in
  under two seconds, and unloads itself after eight idle minutes.
- **Five themes** — System, Daylight, Sand, Graphite, Midnight. Two light, two
  dark, one follows macOS.
- **Small quality-of-life bits** — custom words, snippets, filler-word cleanup,
  four selectable start sounds, searchable history, launch at login.
- **Quiet by design** — menu-bar only, no Dock icon, no background daemons.

## Deliberately not here

No meeting recorder, no notes app, no AI agents, no team spaces, no accounts,
no cloud sync, no analytics. Those are fine products; they are not this one.

## Install

### macOS 14 (Sonoma) or newer

**Requirements:** macOS 14+, Xcode Command Line Tools (full Xcode is not
needed), ~1 GB free disk for the model.

1. Install the command line tools once:

   ```bash
   xcode-select --install
   ```

2. Clone and build:

   ```bash
   git clone https://github.com/Vitali-lab/hush.git
   cd hush
   ./scripts/build_app.sh
   ```

3. Move the app and open it:

   ```bash
   cp -R dist/Hush.app /Applications/
   open /Applications/Hush.app
   ```

   You can also run it straight from `dist/Hush.app`.

4. On first launch, allow:

   - **Microphone** — to hear you.
   - **Accessibility** — for the global shortcut and for pasting into other
     apps. macOS may ask you to restart the app afterwards.
   - **A speech model** — one download (~630 MB), then fully offline.

> The app is signed with a local development identity, not notarized. If you
> copy the built `.app` to another Mac, build it there or clear the quarantine
> flag: `xattr -dr com.apple.quarantine /Applications/Hush.app`.

**Apple Silicon** is the primary target (Neural Engine). Intel Macs build and
run from the same source, but CoreML falls back to CPU/GPU and is slower.

### Windows

**Not available yet.** Hush is a native SwiftUI/AppKit app built on macOS-only
APIs: Accessibility text insertion, CoreML on the Neural Engine, and the menu
bar. A Windows version is technically possible, but it is a separate app, not a
recompile — see [the roadmap note](#windows-and-linux) below.

### Linux

**Not available yet.** Same reason: the system integration layer would need to
be rewritten for X11/Wayland and PulseAudio.

### Uninstall (macOS)

```bash
rm -rf /Applications/Hush.app
rm -rf ~/Library/Application\ Support/Hush
```

Then remove Hush from System Settings → Privacy & Security → Accessibility and
Microphone.

## Use

| Action | Default |
| --- | --- |
| Start / stop dictation | Hold `Fn`, speak, release |
| Cancel while recording | `Esc` |
| Open settings | `⌘ ,` |
| Quit | `⌘ Q` |

The shortcut is fully configurable in **Settings → General → Shortcut**:

1. Click **Record**.
2. Press any key combination, or a single Fn / F1–F20 / modifier key.
3. Choose **Hold** (press and hold) or **Press to toggle** (hands-free).

Any key works. A plain letter will also fire while you type, so a modifier
(⌘, ⌥, ⌃, ⇧) or an F-key is safer. Function keys, Fn, and modifiers can stand
alone. Presets: `Fn`, `Right ⌥`, `Fn ×2`, `⌃⌥Space`.

After release the text is pasted at the cursor. If Accessibility is missing,
Hush copies the text to the clipboard instead and says so in the pill.

### If the shortcut does not work

- **Accessibility** must be enabled for Hush: System Settings → Privacy &
  Security → Accessibility. Toggle it off and on again after rebuilding the app.
- **Fn opens the emoji picker?** Turn off System Settings → Keyboard → Dictation
  (and the “Press 🌐 key” shortcut), or pick another shortcut in Hush.
- **Nothing is pasted?** Check that Accessibility is on; Hush falls back to the
  clipboard and shows “Copied”.
- **Still nothing?** Also enable Input Monitoring for Hush in System Settings →
  Privacy & Security → Input Monitoring, then relaunch the app.

## Languages and themes

The language switch in **Settings → General** (or the `EN / RU` switch in the
menu-bar popover) changes both the interface and the recognition language.

- **English** — Whisper decodes only English.
- **Русский** — Whisper decodes only Russian. The entire interface is translated.

Sound feedback is in **Settings → General → Behavior**. Pick a start sound
(Chime, Bloom, Pluck, Tick) and it plays immediately as a preview. The stop cue
is a soft tick, and the whole thing can be switched off.

Themes are in **Settings → General → Theme**:

| Theme | Mode | Character |
| --- | --- | --- |
| System | follows macOS | default violet accents |
| Daylight | light | cool blue |
| Sand | light | warm terracotta |
| Graphite | dark | steel blue |
| Midnight | dark | deep violet |

Themes also recolor the floating pill, buttons, switches, and the menu-bar
popover.

## Models

| Model | Disk | Speed | Accuracy | Notes |
| --- | --- | --- | --- | --- |
| Large v3 Turbo · Compact | 632 MB | good | best | Default. Compressed turbo weights. |
| Large v3 Turbo | 1.6 GB | good | best | Same model, uncompressed. |
| Small | 486 MB | best | okay | Older Macs, clear speech. |
| Base | 148 MB | best | meh | Tiny, noticeably weaker. |

All models are CoreML builds from
[Argmax WhisperKit](https://github.com/argmaxinc/argmax-oss-swift) and run on the
Apple Neural Engine. Model files live in
`~/Library/Application Support/Hush/Models`.

### Why this model

- **Russian quality**: large-v3 Turbo handles Russian punctuation and mixed
  Russian/English well, and the 626 MB compressed build keeps most of that
  quality.
- **Resources**: in a local test an 8-second Russian clip loaded the model in
  1.8 s and finished in 2.3 s total, with a 130 MB peak RSS.
- **No Python, no server**: CoreML runs inside the app. Nothing to boot, no port
  to babysit, no GPU fan noise.

## Privacy

Hush has no networking code except the one-time model download from Hugging
Face. Audio is kept in memory, transcribed on-device, and discarded after the
text is produced. Nothing is logged to disk unless you keep history, which stays
in your Application Support folder.

## Build and development

```bash
swift build                    # debug binary
swift run Hush                 # run from the terminal
./scripts/build_app.sh         # signed .app in dist/
./scripts/make_icon.sh         # regenerate the icon
```

Hidden helpers used for screenshots and checks:

```bash
.build/debug/Hush --transcribe path/to/audio.wav   # prints a transcription
.build/debug/Hush --selftest                       # text + settings checks
.build/debug/Hush --render-ui /tmp/previews        # renders SwiftUI previews
.build/debug/Hush --capture-ui /tmp/shots          # captures real windows
```

Project layout:

- `Audio/HotkeyManager` — global shortcut via `NSEvent` monitors.
- `Audio/AudioRecorder.swift` — mic tap and resampling to 16 kHz.
- `Speech/TranscriptionService.swift` — lazy model load, decoding options.
- `Text/TextProcessor.swift` — fillers, dictionary, snippets, spacing.
- `System/TextInserter.swift` — paste with clipboard restore.
- `UI/HUD` — non-activating floating pill with a live waveform.
- `UI/Settings` — five small tabs, no wizards.

## Windows and Linux

The core ideas port cleanly; the plumbing does not:

- **UI** — SwiftUI would be replaced by Tauri/Electron or a native WinUI app.
- **Audio** — WASAPI (Windows) / PulseAudio or PipeWire (Linux) instead of
  AVFoundation.
- **Inference** — no CoreML/ANE. Use `whisper.cpp` with Vulkan/CUDA/DirectML or
  CPU, or `whisper-onnx`. A 632 MB turbo model still runs well on a modern CPU,
  but expect 2–5× realtime instead of 10–30×.
- **Insertion** — `SendInput` + UIAutomation on Windows, xdotool/ydotool or an
  input-method on Linux.
- **Packaging** — MSIX/NSIS on Windows, AppImage/deb/rpm on Linux.

So a Windows build is realistic, but it is a second app that shares the text
pipeline and the model choice, not a checkbox. A cross-platform rewrite around a
small Rust/Tauri core is the sane path if that becomes a goal.

## Credits

- [WhisperKit](https://github.com/argmaxinc/argmax-oss-swift) by Argmax — MIT
- [Whisper](https://github.com/openai/whisper) by OpenAI — MIT
- Inspired by [Wispr Flow](https://wisprflow.ai) and the open-source
  [OpenWhispr](https://github.com/OpenWhispr/openwhispr) — MIT

Hush itself is MIT licensed. See [LICENSE](LICENSE).

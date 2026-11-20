# Development

Internal notes for building and changing Hush. User-facing docs live in
[README.md](README.md).

## Build

```bash
swift build                    # debug binary
swift run Hush                 # run from the terminal
./scripts/build_app.sh         # signed .app in dist/
./scripts/make_icon.sh         # regenerate scripts/AppIcon.icns
```

Requires macOS 14+, Swift 6 command line tools, and no full Xcode.

`build_app.sh` signs with the first `Apple Development` identity it finds, or
ad-hoc when there is none. The app is not notarized: a downloaded build needs
right-click → Open or `xattr -dr com.apple.quarantine`.

## Release

```bash
./scripts/release.sh
```

The script builds `dist/Hush.app`, checks the signature, creates a DMG with an
Applications symlink and a short README, zips the app, writes
`dist/SHA256SUMS.txt`, and prints the `gh release create` command. Uploading is
left explicit so a release is never published by accident.

## Project layout

- `Audio/HotkeyManager` — global shortcut via `NSEvent` monitors.
- `Audio/AudioRecorder.swift` — mic tap and resampling to 16 kHz.
- `Audio/FeedbackSoundPlayer.swift` — synthesized PCM cues.
- `Speech/TranscriptionService.swift` — lazy model load, decoding options.
- `Text/TextProcessor.swift` — fillers, dictionary, snippets, spacing.
- `System/TextInserter.swift` — paste with clipboard restore.
- `UI/HUD` — non-activating floating pill with a live waveform.
- `UI/Settings` — five tabs, no wizards.
- `Support/AppLanguage.swift` — inline EN/RU localization.

Settings and history live in `~/Library/Application Support/Hush/`. An older
`Sotto` folder is migrated on first launch.

## Development flags

```bash
.build/debug/Hush --transcribe path/to/audio.wav   # print a transcription
.build/debug/Hush --selftest                       # text/settings checks
.build/debug/Hush --render-ui /tmp/previews        # render SwiftUI snapshots
.build/debug/Hush --capture-ui /tmp/shots          # capture real windows
.build/debug/Hush --capture-menu /tmp/menu         # capture the popover
.build/debug/Hush --play-sound chime               # play a feedback cue
.build/debug/Hush --verbose                        # log phases and model loads
```

The `--capture-ui` and `--capture-menu` flags bypass the single-instance guard.

## Porting notes

Windows and Linux are separate apps, not a recompile:

- **UI** — SwiftUI would be replaced by Tauri/Electron or native WinUI.
- **Audio** — WASAPI on Windows, PulseAudio/PipeWire on Linux.
- **Inference** — no CoreML/ANE. Use `whisper.cpp` with Vulkan/CUDA/DirectML or
  CPU. Expect 2–5× realtime instead of 10–30×.
- **Insertion** — `SendInput` + UIAutomation on Windows, xdotool/ydotool or an
  input method on Linux.
- **Packaging** — MSIX/NSIS on Windows, AppImage/deb/rpm on Linux.

A cross-platform Rust/Tauri core plus a web UI is the sane path if that becomes
a goal.

# Hush

**Speak softly. We'll do the typing.**

On-device dictation for macOS. Hold a shortcut, say what you mean, release — the
words appear at the cursor in any app. No account, no cloud, no telemetry.

[**Download Hush for macOS**](https://github.com/Vitali-lab/hush/releases/latest/download/Hush-macOS-arm64.dmg) · [Русская версия →](README.ru.md)

```
macOS 14+ · Apple Silicon · ~8 MB plus a one-time 632 MB model
```

## Download

| File | Link |
| --- | --- |
| Installer (DMG) | [Hush-macOS-arm64.dmg](https://github.com/Vitali-lab/hush/releases/latest/download/Hush-macOS-arm64.dmg) |
| Zip archive | [Hush-macOS-arm64.zip](https://github.com/Vitali-lab/hush/releases/latest/download/Hush-macOS-arm64.zip) |
| Checksums | [SHA256SUMS.txt](https://github.com/Vitali-lab/hush/releases/latest/download/SHA256SUMS.txt) |

Hush is signed with a development certificate and is **not notarized yet**. On
the first launch macOS may ask for confirmation: right-click **Hush → Open**, or
run:

```bash
xattr -dr com.apple.quarantine /Applications/Hush.app
```

## Features

- **Dictate anywhere** — Slack, Mail, Cursor, Terminal, a browser. The text is
  pasted at the focused cursor, so any text field works.
- **Fully offline** — Whisper `large-v3` Turbo in CoreML, running on the Apple
  Neural Engine. Audio is recorded in memory and never uploaded.
- **Light on resources** — roughly 130–200 MB RAM while transcribing; the model
  loads in under two seconds and unloads after eight idle minutes.
- **Two languages, one switch** — English or Russian for both the interface and
  recognition. RU listens only in Russian, EN only in English.
- **Any shortcut** — hold Fn, hold Right Option, use a key combo, or record your
  own key. Hold-to-talk or hands-free toggle.
- **Five themes** — System, Daylight, Sand, Graphite, Midnight. Two light, two
  dark, one follows macOS.
- **Small comforts** — custom words, snippets, filler-word cleanup, four
  selectable start sounds, searchable history, launch at login.
- **Quiet by design** — menu-bar only, no Dock icon, no background daemons.

## Install

1. Download the DMG and open it.
2. Drag **Hush** into **Applications**.
3. Launch Hush and allow:
   - **Microphone** — to hear you.
   - **Accessibility** — for the global shortcut and pasting text into other
     apps. macOS may ask you to restart the app afterwards.
   - **A speech model** — one download (~630 MB), then fully offline.
4. Hold your shortcut, speak, release.

If the shortcut still does nothing, also enable **Input Monitoring** for Hush and
relaunch the app.

## Use

| Action | Default |
| --- | --- |
| Start / stop dictation | Hold `Fn`, speak, release |
| Cancel while recording | `Esc` |
| Open settings | `⌘ ,` |
| Quit | `⌘ Q` |

The shortcut is configurable in **Settings → General → Shortcut**:

1. Click **Record**.
2. Press any key combination, or a single Fn / F1–F20 / modifier key.
3. Choose **Hold** or **Press to toggle**.

Any key works. A plain letter will also fire while you type, so a modifier
(⌘, ⌥, ⌃, ⇧) or an F-key is safer. Presets: `Fn`, `Right ⌥`, `Fn ×2`,
`⌃⌥Space`.

After release the text is pasted at the cursor. If Accessibility is missing,
Hush copies the text to the clipboard instead.

## Languages, sounds, themes

Switch the language in **Settings → General** or with `EN / RU` in the menu-bar
popover. It changes both the interface and the recognition language.

Start sounds live in **Settings → General → Behavior**: Chime, Bloom, Pluck, or
Tick. Each one previews when selected; the stop cue is a soft tick, and the whole
feedback can be turned off.

Themes are in **Settings → General → Theme**:

| Theme | Mode | Character |
| --- | --- | --- |
| System | follows macOS | default violet accents |
| Daylight | light | cool blue |
| Sand | light | warm terracotta |
| Graphite | dark | steel blue |
| Midnight | dark | deep violet |

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

## Privacy

Hush has no networking code except the one-time model download from Hugging
Face. Audio is kept in memory, transcribed on-device, and discarded after the
text is produced. Nothing is logged to disk unless you keep history, which stays
in your Application Support folder.

## Troubleshooting

- **The shortcut does not fire** — enable Accessibility for Hush, then toggle it
  off and on after installing a new build. If it still does not work, enable
  Input Monitoring as well and relaunch.
- **Fn opens the emoji picker** — turn off System Settings → Keyboard → Dictation
  (and the “Press 🌐 key” shortcut), or pick another shortcut in Hush.
- **Nothing is pasted** — check Accessibility; Hush falls back to the clipboard.
- **The model download fails** — check the network and retry from
  **Settings → Model**.

## Build from source

Requires macOS 14+ and the Xcode Command Line Tools. Full Xcode is not needed.

```bash
xcode-select --install
git clone https://github.com/Vitali-lab/hush.git
cd hush
./scripts/build_app.sh
open dist/Hush.app
```

See [DEVELOPMENT.md](DEVELOPMENT.md) for the project layout, development flags,
and porting notes.

## Platforms

macOS 14+ on Apple Silicon. Windows and Linux are not supported yet.

## Credits

- [WhisperKit](https://github.com/argmaxinc/argmax-oss-swift) by Argmax — MIT
- [Whisper](https://github.com/openai/whisper) by OpenAI — MIT

Hush is MIT licensed. See [LICENSE](LICENSE).

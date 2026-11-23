# Hush for Windows (beta)

A native Windows port of Hush: hold a shortcut, speak, and the text is pasted
at the cursor. Speech recognition runs locally with whisper.cpp; nothing is
uploaded.

## Status

This is a **first beta**. The macOS app is the stable release; the Windows app
shares the same settings model, text cleanup, dictionary, snippets, history,
and monochrome pill, but the Windows system layer is new and needs testing on
real machines.

Tested in CI only so far:

- core text/settings tests on `windows-latest`;
- self-contained `win-x64` publish;
- WPF/XAML compiles with .NET 10.

Microphone capture, the global hook, and text insertion must be verified on a
real Windows PC. That is what the beta is for.

## Requirements

- Windows 11 x64 (the Whisper.net CPU runtime targets Windows 11/Server 2022)
- A CPU with AVX2
- ~700 MB free disk for the first model
- Microsoft Visual C++ 2015–2022 Redistributable x64 if `whisper.dll` fails to
  load

## Run

1. Download `Hush-Windows-x64.zip` from the latest release.
2. Extract it anywhere. The folder is portable; no installer.
3. Run `Hush.exe`.

SmartScreen may warn because the build is unsigned. Choose **More info → Run
anyway** if you trust the download, or build it yourself.

On first launch:

1. Open **Settings → Model** and download the default model (574 MB).
2. Allow microphone access if Windows asks.
3. Press **Right Alt** and speak. The default follows the macOS hold-to-talk
   model; **Ctrl+Alt+Space** is available as a toggle preset.

Settings, model files, and history live in `%APPDATA%\Hush`.

## Build

From a Windows machine with .NET 10 SDK:

```powershell
dotnet run --project windows/tests/Hush.Core.Tests/Hush.Core.Tests.csproj
dotnet publish windows/src/Hush.Windows/Hush.Windows.csproj `
  -c Release -r win-x64 --self-contained true -o publish
.\publish\Hush.exe
```

Or use the ready GitHub Actions workflow in `windows/ci/windows.yml`. Copy it to
`.github/workflows/windows.yml` after granting the CLI the `workflow` scope:

```bash
gh auth refresh -s workflow
```

The first beta zip was built with `dotnet publish` and is attached to the
GitHub release; the workflow is there for repeatable builds once the scope is
granted.

## Architecture

- WPF/.NET 10 UI, shared `Hush.Core` for settings, text processing, and models.
- `WasapiCapture` + Media Foundation resampler → 16 kHz mono WAV.
- `Whisper.net` + whisper.cpp CPU runtime.
- Low-level keyboard hook (`WH_KEYBOARD_LL`) for any key combination and
  modifier-only keys.
- `SendInput` Ctrl+V with clipboard restore.
- Tray icon, registry autostart, single-instance mutex.

## Known limitations

- **Fn is not available.** Windows keyboards handle Fn in firmware and do not
  expose it to applications. Right Alt is the default instead.
- Input is not received while an elevated app has focus (Windows UIPI).
- The build is unsigned; SmartScreen will warn.
- CPU inference only. A GPU backend can be added later without changing the UI.
- The first beta has no updater and no installer.

## Download

`https://github.com/Vitali-lab/hush/releases/latest/download/Hush-Windows-x64.zip`

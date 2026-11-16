import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeader(
                title: "About",
                subtitle: "A small, quiet dictation app. No account, no cloud, no telemetry."
            )

            Card {
                HStack(spacing: 14) {
                    BrandMark(size: 46)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Sotto")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                        Text("Version \(AppInfo.version) · MIT license")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                Text("Sotto is a local-first take on Wispr Flow: a global shortcut, a tiny floating pill, and your words at the cursor. Audio is recorded in memory and never uploaded.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Card {
                Text("Under the hood")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))

                VStack(alignment: .leading, spacing: 9) {
                    bullet("waveform", "Whisper large-v3 Turbo", "converted to CoreML by Argmax WhisperKit, running on the Neural Engine")
                    bullet("gauge.with.dots.needle.33percent", "~400–900 MB RAM", "while transcribing, far less than a browser tab")
                    bullet("lock.shield", "Fully offline", "after the one-time model download")
                    bullet("bolt", "10–30× realtime", "on Apple Silicon, so a minute of speech takes a few seconds")
                }
            }

            Card {
                Text("Shortcuts")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))

                shortcutRow("Start / stop dictation", "Hold Fn")
                shortcutRow("Cancel while recording", "Esc")
                shortcutRow("Open settings", "⌘ ,")
                shortcutRow("Quit", "⌘ Q")
            }

            HStack(spacing: 12) {
                Link(destination: URL(string: AppInfo.repository)!) {
                    Label("GitHub", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(SecondaryButtonStyle())

                Spacer()

                Text("Built on WhisperKit by Argmax · Whisper by OpenAI")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func bullet(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 18)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func shortcutRow(_ title: String, _ keys: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
            Spacer()
            KeyCap(text: keys)
        }
    }
}

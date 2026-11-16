import SwiftUI

struct AboutView: View {
    @ObservedObject var model: AppModel

    private var t: Loc { Loc(model.settings.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeader(
                title: t("About", "О приложении"),
                subtitle: t(
                    "A small, quiet dictation app. No account, no cloud, no telemetry.",
                    "Маленькое тихое приложение для диктовки. Без аккаунта, облака и телеметрии."
                )
            )

            Card {
                HStack(spacing: 14) {
                    BrandMark(size: 46)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Hush")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                        Text(t(
                            "Version \(AppInfo.version) · MIT license",
                            "Версия \(AppInfo.version) · лицензия MIT"
                        ))
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                Text(t(
                    "Hush is a local-first take on Wispr Flow: a global shortcut, a tiny floating pill, and your words at the cursor. Audio is recorded in memory and never uploaded.",
                    "Hush — локальная альтернатива Wispr Flow: глобальный хоткей, маленькая плавающая пилюля и твои слова у курсора. Аудио живёт в памяти и никуда не отправляется."
                ))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Card {
                Text(t("Under the hood", "Под капотом"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))

                VStack(alignment: .leading, spacing: 9) {
                    bullet(
                        "waveform",
                        "Whisper large-v3 Turbo",
                        t(
                            "converted to CoreML by Argmax WhisperKit, running on the Neural Engine",
                            "CoreML-сборка от Argmax WhisperKit, работает на Neural Engine"
                        )
                    )
                    bullet(
                        "gauge.with.dots.needle.33percent",
                        t("~130–200 MB RAM", "~130–200 МБ памяти"),
                        t(
                            "while transcribing, less than a browser tab",
                            "во время распознавания — меньше, чем вкладка браузера"
                        )
                    )
                    bullet(
                        "lock.shield",
                        t("Fully offline", "Полностью офлайн"),
                        t(
                            "after the one-time model download",
                            "после одной загрузки модели"
                        )
                    )
                    bullet(
                        "bolt",
                        t("10–30× realtime", "10–30× быстрее реального времени"),
                        t(
                            "on Apple Silicon, so a minute of speech takes a few seconds",
                            "на Apple Silicon: минута речи — пара секунд"
                        )
                    )
                }
            }

            Card {
                Text(t("Shortcuts", "Горячие клавиши"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))

                shortcutRow(t("Start / stop dictation", "Старт / стоп диктовки"), t("Hold Fn", "Удерживай Fn"))
                shortcutRow(t("Cancel while recording", "Отмена во время записи"), "Esc")
                shortcutRow(t("Open settings", "Открыть настройки"), "⌘ ,")
                shortcutRow(t("Quit", "Выход"), "⌘ Q")
            }

            HStack(spacing: 12) {
                Link(destination: URL(string: AppInfo.repository)!) {
                    Label("GitHub", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(SecondaryButtonStyle())

                Spacer()

                Text("WhisperKit by Argmax · Whisper by OpenAI")
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

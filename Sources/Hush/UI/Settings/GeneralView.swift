import AppKit
import Combine
import SwiftUI

struct GeneralView: View {
    @ObservedObject var model: AppModel
    @Binding var tab: SettingsTab

    private var t: Loc { Loc(model.settings.language) }

    private var modelInstalled: Bool {
        ModelCatalog.isInstalled(model.settings.modelID)
    }

    private var setupDone: Bool {
        model.isMicrophoneGranted && model.isAccessibilityGranted && modelInstalled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeader(
                title: t("General", "Основное"),
                subtitle: t(
                    "Hold a key, speak, release. Your words land at the cursor.",
                    "Зажми клавишу, говори, отпусти. Текст появится у курсора."
                )
            )

            if !setupDone {
                setupCard
            }

            ShortcutCard(model: model)
            languageCard
            ThemeCard(model: model)
            behaviorCard

            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                Text(t(
                    "Audio and text never leave this Mac. No account, no cloud.",
                    "Аудио и текст не покидают этот Mac. Без аккаунта и облака."
                ))
                    .font(.system(size: 11.5))
            }
            .foregroundStyle(.secondary)
            .padding(.leading, 2)
        }
    }

    // MARK: - Setup

    private var setupCard: some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("Finish setup", "Заверши настройку"))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text(t(
                        "Three steps and you can dictate anywhere.",
                        "Три шага — и можно диктовать где угодно."
                    ))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                SetupProgress(value: setupProgress / 3)
                    .frame(width: 84)
            }

            Divider().opacity(0.5)

            SetupStep(
                done: model.isMicrophoneGranted,
                icon: "mic",
                title: t("Microphone", "Микрофон"),
                subtitle: model.isMicrophoneGranted
                    ? t("Access granted", "Доступ выдан")
                    : t("Needed to hear you", "Нужен, чтобы слышать тебя"),
                actionTitle: t("Allow", "Разрешить")
            ) {
                model.requestMicrophone()
            }

            SetupStep(
                done: model.isAccessibilityGranted,
                icon: "hand.raised",
                title: t("Accessibility", "Универсальный доступ"),
                subtitle: model.isAccessibilityGranted
                    ? t("Access granted — text can be inserted", "Доступ выдан — текст можно вставлять")
                    : t("Needed for the hotkey and pasting text", "Нужен для хоткея и вставки текста"),
                actionTitle: t("Open Settings", "Открыть настройки")
            ) {
                model.requestAccessibility()
            }

            SetupStep(
                done: modelInstalled,
                icon: "cpu",
                title: t("Speech model", "Речевая модель"),
                subtitle: modelInstalled
                    ? t(
                        "\(ModelCatalog.spec(id: model.settings.modelID)?.name(model.settings.language) ?? "Model") is installed",
                        "\(ModelCatalog.spec(id: model.settings.modelID)?.name(model.settings.language) ?? "Модель") установлена"
                    )
                    : t("Download a local model once", "Скачай локальную модель один раз"),
                actionTitle: t("Choose", "Выбрать")
            ) {
                withAnimation(.snappy(duration: 0.22)) {
                    tab = .model
                }
            }

            Text(t(
                "After granting Accessibility, macOS may ask you to restart Hush.",
                "После выдачи доступа macOS может попросить перезапустить Hush."
            ))
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary.opacity(0.8))
        }
    }

    private var setupProgress: Double {
        var value = 0.0
        if model.isMicrophoneGranted { value += 1 }
        if model.isAccessibilityGranted { value += 1 }
        if modelInstalled { value += 1 }
        return value
    }

    // MARK: - Language

    private var languageCard: some View {
        Card {
            Text(t("Language", "Язык"))
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            HStack(spacing: 8) {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        model.settings.language = language
                    } label: {
                        HStack(spacing: 6) {
                            Text(language.displayName)
                            Text(language.shortName)
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule().fill(
                                        model.settings.language == language
                                            ? Theme.accent.opacity(0.18)
                                            : Color.primary.opacity(0.05)
                                    )
                                )
                        }
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(model.settings.language == language
                                      ? Theme.accent.opacity(0.14)
                                      : Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(
                                    model.settings.language == language
                                        ? Theme.accent.opacity(0.5)
                                        : Color.clear,
                                    lineWidth: 1
                                )
                        )
                        .foregroundStyle(model.settings.language == language ? Theme.accent : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(t(
                "Switches the interface and the dictation language. Russian listens only in Russian, English only in English.",
                "Переключает интерфейс и язык распознавания. Русский — диктовка только по-русски, English — только по-английски."
            ))
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Behavior

    private var behaviorCard: some View {
        Card {
            Text(t("Behavior", "Поведение"))
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            ToggleRow(
                title: t("Paste automatically", "Вставлять автоматически"),
                subtitle: t(
                    "Insert text at the cursor. Turn off to copy to clipboard only.",
                    "Вставлять текст у курсора. Выключи, чтобы только копировать в буфер."
                ),
                isOn: $model.settings.autoPaste
            )

            Divider().opacity(0.5)

            ToggleRow(
                title: t("Remove filler words", "Убирать слова-паразиты"),
                subtitle: t(
                    "Drops “um”, “uh”, “ээ”, “эм” and similar sounds.",
                    "Убирает «ээ», «эм» и подобные звуки."
                ),
                isOn: $model.settings.removeFillers
            )

            Divider().opacity(0.5)

            ToggleRow(
                title: t("Sound feedback", "Звуковой отклик"),
                subtitle: t(
                    "A short cue when recording starts and stops.",
                    "Короткий звук в начале и конце записи."
                ),
                isOn: $model.settings.playFeedbackSound
            )

            if model.settings.playFeedbackSound {
                SoundPicker(model: model)
            }

            Divider().opacity(0.5)

            ToggleRow(
                title: t("Launch at login", "Запускать при входе"),
                subtitle: t(
                    "Keep Hush ready in the menu bar after a restart.",
                    "Hush будет ждать в меню-баре после перезагрузки."
                ),
                isOn: $model.settings.launchAtLogin
            )
        }
    }
}

// MARK: - Sound

private struct SoundPicker: View {
    @ObservedObject var model: AppModel

    private var t: Loc { Loc(model.settings.language) }

    var body: some View {
        HStack(spacing: 6) {
            Text(t("Start sound", "Звук старта"))
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)

            Spacer(minLength: 6)

            ForEach(FeedbackSound.allCases) { sound in
                Button {
                    model.settings.feedbackSound = sound
                    FeedbackSoundPlayer.shared.play(sound)
                } label: {
                    Text(sound.name(model.settings.language))
                        .font(.system(size: 10.5, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(
                                model.settings.feedbackSound == sound
                                    ? Theme.accent.opacity(0.14)
                                    : Color.primary.opacity(0.04)
                            )
                        )
                        .overlay(
                            Capsule().strokeBorder(
                                model.settings.feedbackSound == sound
                                    ? Theme.accent.opacity(0.45)
                                    : Color.clear,
                                lineWidth: 1
                            )
                        )
                        .foregroundStyle(model.settings.feedbackSound == sound ? Theme.accent : .secondary)
                }
                .buttonStyle(.plain)
                .help(sound.detail(model.settings.language))
            }
        }
        .padding(.leading, 2)
        .padding(.top, 2)
        .animation(.easeOut(duration: 0.15), value: model.settings.feedbackSound)
    }
}

// MARK: - Shortcut

private struct ShortcutCard: View {
    @ObservedObject var model: AppModel

    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var pendingWork: DispatchWorkItem?
    @State private var errorText: String?

    private var t: Loc { Loc(model.settings.language) }

    var body: some View {
        Card {
            HStack {
                Text(t("Shortcut", "Горячая клавиша"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
                Text(t("Any key, with or without modifiers", "Любая клавиша, с модификаторами или без"))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(isRecording ? t("Press keys…", "Нажми клавиши…") : model.settings.hotkey.display(model.settings.language))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(isRecording ? Theme.accent : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(isRecording ? Theme.accent.opacity(0.08) : Color.primary.opacity(0.045))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(
                            isRecording ? Theme.accent.opacity(0.5) : Color.primary.opacity(0.07),
                            lineWidth: 1
                        )
                )

                Button(isRecording ? t("Cancel", "Отмена") : t("Record", "Записать")) {
                    isRecording ? stopRecording() : beginRecording()
                }
                .buttonStyle(isRecording ? AnyButtonStyle(SecondaryButtonStyle()) : AnyButtonStyle(PrimaryButtonStyle()))
                .frame(width: 108)
            }

            HStack(spacing: 8) {
                ForEach(HotkeyMode.allCases) { mode in
                    Button {
                        setMode(mode)
                    } label: {
                        Text(mode.title(model.settings.language))
                            .font(.system(size: 11.5, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(
                                    model.settings.hotkey.mode == mode
                                        ? Theme.accent.opacity(0.14)
                                        : Color.primary.opacity(0.04)
                                )
                            )
                            .foregroundStyle(model.settings.hotkey.mode == mode ? Theme.accent : .secondary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }

            HStack(spacing: 6) {
                ForEach(HotkeyBinding.presets, id: \.self) { preset in
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            model.settings.hotkey = preset
                        }
                    } label: {
                        Text(preset.display(model.settings.language))
                            .font(.system(size: 10.5, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(model.settings.hotkey == preset
                                          ? Theme.accent.opacity(0.14)
                                          : Color.primary.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(
                                        model.settings.hotkey == preset
                                            ? Theme.accent.opacity(0.4)
                                            : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                            .foregroundStyle(model.settings.hotkey == preset ? Theme.accent : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }

            if let errorText {
                Text(errorText)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.danger)
            } else if model.settings.hotkey.needsModifierWarning {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10))
                    Text(t(
                        "A single key will also fire while you type. A modifier or an F-key is safer.",
                        "Одна клавиша будет срабатывать и во время набора. Модификатор или F-клавиша надёжнее."
                    ))
                        .font(.system(size: 10.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Theme.amber)
            } else {
                Text(t(
                    "Any key works. Modifiers, F-keys, and Fn can stand alone.",
                    "Работает любая клавиша. Модификаторы, F-клавиши и Fn могут быть сами по себе."
                ))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }

            if model.settings.hotkey.keyCode == 63 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10))
                    Text(t(
                        "macOS may also open the emoji picker on Fn. Turn off the system dictation shortcut to avoid clashes.",
                        "macOS тоже может открывать эмодзи на Fn. Отключи системную диктовку, чтобы не конфликтовало."
                    ))
                        .font(.system(size: 10.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(.secondary)
            }
        }
        .onDisappear { stopRecording() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            if isRecording { stopRecording() }
        }
    }

    private func beginRecording() {
        guard monitor == nil else { return }
        errorText = nil
        isRecording = true

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handle(event)
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        pendingWork?.cancel()
        pendingWork = nil
        isRecording = false
    }

    private func handle(_ event: NSEvent) {
        pendingWork?.cancel()
        pendingWork = nil

        if event.type == .keyDown {
            if event.keyCode == 53 { // Esc cancels the recorder
                stopRecording()
                return
            }

            let binding = HotkeyBinding(
                keyCode: event.keyCode,
                modifiers: event.modifierFlags,
                mode: model.settings.hotkey.mode,
                character: event.charactersIgnoringModifiers ?? ""
            )
            commit(binding)
            return
        }

        guard event.type == .flagsChanged,
              HotkeyBinding.isModifierKey(event.keyCode) else { return }

        let keyCode = event.keyCode
        let flags = event.modifierFlags

        // Only capture the press, not the release, otherwise a quick tap would
        // store an empty modifier mask and show the wrong symbol.
        let isDown: Bool
        switch keyCode {
        case 63: isDown = flags.contains(.function)
        case 54, 55: isDown = flags.contains(.command)
        case 58, 61: isDown = flags.contains(.option)
        case 59, 62: isDown = flags.contains(.control)
        case 56, 60: isDown = flags.contains(.shift)
        default: isDown = false
        }
        guard isDown else { return }
        let work = DispatchWorkItem { [self] in
            let binding = HotkeyBinding(
                keyCode: keyCode,
                modifiers: flags,
                mode: model.settings.hotkey.mode
            )
            if binding.isValid {
                apply(binding)
            }
        }
        pendingWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    private func commit(_ binding: HotkeyBinding) {
        guard binding.isValid else {
            errorText = t(
                "Add ⌘, ⌥, ⌃ or ⇧, or pick a function key.",
                "Добавь ⌘, ⌥, ⌃ или ⇧, либо выбери F-клавишу."
            )
            return
        }
        apply(binding)
    }

    private func apply(_ binding: HotkeyBinding) {
        withAnimation(.snappy(duration: 0.2)) {
            model.settings.hotkey = binding
        }
        errorText = nil
        stopRecording()
    }

    private func setMode(_ mode: HotkeyMode) {
        var binding = model.settings.hotkey
        binding.mode = mode
        if mode == .hold {
            binding.doubleTap = false
        }
        withAnimation(.snappy(duration: 0.2)) {
            model.settings.hotkey = binding
        }
    }
}

/// Erases the concrete button style so the two branches can share a modifier position.
private struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView

    init<S: ButtonStyle>(_ style: S) {
        make = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        make(configuration)
    }
}

// MARK: - Theme

private struct ThemeCard: View {
    @ObservedObject var model: AppModel

    private var t: Loc { Loc(model.settings.language) }

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 6),
        count: 5
    )

    var body: some View {
        Card {
            Text(t("Theme", "Тема"))
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(AppTheme.allCases) { theme in
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            model.settings.theme = theme
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [theme.palette.accentBright, theme.palette.pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(height: 30)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(
                                            Color.white.opacity(theme.isDark ? 0.12 : 0.4),
                                            lineWidth: 1
                                        )
                                )

                            Text(theme.name(model.settings.language))
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                        .padding(7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(model.settings.theme == theme
                                      ? Theme.accent.opacity(0.10)
                                      : Color.primary.opacity(0.03))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(
                                    model.settings.theme == theme
                                        ? Theme.accent.opacity(0.5)
                                        : Color.primary.opacity(0.06),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(t(
                "System follows macOS. The others lock light or dark and recolor accents.",
                "Системная следует за macOS. Остальные фиксируют светлую или тёмную и меняют акценты."
            ))
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
        }
    }
}

import SwiftUI

struct GeneralView: View {
    @ObservedObject var model: AppModel
    @Binding var tab: SettingsTab

    private var modelInstalled: Bool {
        ModelCatalog.isInstalled(model.settings.modelID)
    }

    private var setupDone: Bool {
        model.isMicrophoneGranted && model.isAccessibilityGranted && modelInstalled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeader(
                title: "General",
                subtitle: "Hold a key, speak, release. Your words land at the cursor."
            )

            if !setupDone {
                setupCard
            }

            hotkeyCard
            languageCard
            behaviorCard

            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                Text("Audio and text never leave this Mac. No account, no cloud.")
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
                    Text("Finish setup")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text("Three steps and you can dictate anywhere.")
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
                title: "Microphone",
                subtitle: model.isMicrophoneGranted ? "Access granted" : "Needed to hear you",
                actionTitle: "Allow"
            ) {
                model.requestMicrophone()
            }

            SetupStep(
                done: model.isAccessibilityGranted,
                icon: "hand.raised",
                title: "Accessibility",
                subtitle: model.isAccessibilityGranted
                    ? "Access granted — text can be inserted"
                    : "Needed for the hotkey and pasting text",
                actionTitle: "Open Settings"
            ) {
                model.requestAccessibility()
            }

            SetupStep(
                done: modelInstalled,
                icon: "cpu",
                title: "Speech model",
                subtitle: modelInstalled
                    ? "\(ModelCatalog.spec(id: model.settings.modelID)?.name ?? "Model") is installed"
                    : "Download a local model once",
                actionTitle: "Choose"
            ) {
                withAnimation(.snappy(duration: 0.22)) {
                    tab = .model
                }
            }

            Text("After granting Accessibility, macOS may ask you to restart Sotto.")
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

    // MARK: - Hotkey

    private var hotkeyCard: some View {
        Card {
            HStack {
                Text("Shortcut")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
                Text(model.settings.hotkey.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(HotkeyChoice.allCases) { choice in
                    HotkeyOption(
                        choice: choice,
                        isSelected: model.settings.hotkey == choice
                    ) {
                        model.settings.hotkey = choice
                    }
                }
            }

            if model.settings.hotkey == .fnHold || model.settings.hotkey == .fnDoubleTap {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10))
                    Text("macOS may also open the emoji picker on Fn. Turn off the system dictation shortcut to avoid clashes.")
                        .font(.system(size: 10.5))
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Language

    private var languageCard: some View {
        Card {
            Text("Language")
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            HStack(spacing: 8) {
                ForEach(LanguageChoice.allCases) { choice in
                    Button {
                        model.settings.language = choice
                    } label: {
                        Text(choice.title)
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(model.settings.language == choice
                                          ? Theme.accent.opacity(0.14)
                                          : Color.primary.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(
                                        model.settings.language == choice
                                            ? Theme.accent.opacity(0.5)
                                            : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                            .foregroundStyle(model.settings.language == choice ? Theme.accent : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Auto-detect works well for long phrases. Pick a language for short commands and mixed speech.")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Behavior

    private var behaviorCard: some View {
        Card {
            Text("Behavior")
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            ToggleRow(
                title: "Paste automatically",
                subtitle: "Insert text at the cursor. Turn off to copy to clipboard only.",
                isOn: $model.settings.autoPaste
            )

            Divider().opacity(0.5)

            ToggleRow(
                title: "Remove filler words",
                subtitle: "Drops “um”, “uh”, “ээ”, “эм” and similar sounds.",
                isOn: $model.settings.removeFillers
            )

            Divider().opacity(0.5)

            ToggleRow(
                title: "Sound feedback",
                subtitle: "A soft tick when recording starts and stops.",
                isOn: $model.settings.playFeedbackSound
            )

            Divider().opacity(0.5)

            ToggleRow(
                title: "Launch at login",
                subtitle: "Keep Sotto ready in the menu bar after a restart.",
                isOn: $model.settings.launchAtLogin
            )
        }
    }
}

private struct HotkeyOption: View {
    let choice: HotkeyChoice
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 9) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Theme.accent : Color.primary.opacity(0.22), lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                    if isSelected {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 7, height: 7)
                    }
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(choice.title)
                        .font(.system(size: 12, weight: .semibold))
                    Text(choice.detail)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected
                          ? Theme.accent.opacity(0.10)
                          : Color.primary.opacity(hovering ? 0.055 : 0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent.opacity(0.45) : Color.primary.opacity(0.06), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.14), value: hovering)
        .animation(.easeOut(duration: 0.16), value: isSelected)
    }
}

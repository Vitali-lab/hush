import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let model: AppModel
    private let onSettings: () -> Void
    private let onQuit: () -> Void
    private var cancellables: Set<AnyCancellable> = []
    private var previousApp: NSRunningApplication?

    init(model: AppModel, onSettings: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.model = model
        self.onSettings = onSettings
        self.onQuit = onQuit
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Hush")
            button.image?.isTemplate = true
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Hush · \(model.settings.hotkey.display(model.settings.language))"
        }

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        let hosting = NSHostingController(
            rootView: MenuPopoverView(
                model: model,
                onToggle: { [weak self] in self?.startFromPopover() },
                onSettings: onSettings,
                onQuit: onQuit
            )
        )
        hosting.view.layoutSubtreeIfNeeded()
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting

        model.$phase
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] phase in
                self?.updateIcon(for: phase)
                if case .listening = phase {
                    self?.popover.performClose(nil)
                }
            }
            .store(in: &cancellables)

        model.$settings
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] settings in
                self?.statusItem.button?.toolTip = "Hush · \(settings.hotkey.display(settings.language))"
            }
            .store(in: &cancellables)
    }

    private func updateIcon(for phase: DictationPhase) {
        let name: String
        switch phase {
        case .listening: name = "mic.fill"
        case .transcribing: name = "waveform.badge.magnifyingglass"
        case .done: name = "checkmark"
        default: name = "waveform"
        }
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Hush")
            ?? NSImage(systemSymbolName: "waveform", accessibilityDescription: "Hush")
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    @objc private func statusItemClicked() {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            showContextMenu()
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            previousApp = NSWorkspace.shared.frontmostApplication
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func showPopoverForPreview() {
        guard let button = statusItem.button else { return }
        previousApp = NSWorkspace.shared.frontmostApplication
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func startFromPopover() {
        popover.performClose(nil)

        if let previousApp, previousApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp.activate(options: [])
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            self?.model.toggleDictation()
        }
    }

    private func showContextMenu() {
        let t = Loc(model.settings.language)
        let menu = NSMenu()
        menu.addItem(
            withTitle: t("Settings…", "Настройки…"),
            action: #selector(openSettings),
            keyEquivalent: ","
        ).target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: t("Quit Hush", "Завершить Hush"),
            action: #selector(quit),
            keyEquivalent: "q"
        ).target = self
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openSettings() {
        onSettings()
    }

    @objc private func quit() {
        onQuit()
    }
}

struct MenuPopoverView: View {
    @ObservedObject var model: AppModel
    let onToggle: () -> Void
    let onSettings: () -> Void
    let onQuit: () -> Void

    @State private var copied = false

    private var t: Loc { Loc(model.settings.language) }

    private var installed: Bool {
        ModelCatalog.isInstalled(model.settings.modelID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if !model.isAccessibilityGranted { permissionWarning }
            if !installed { modelWarning }
            transcriptCard
            statsRow
            actions
        }
        .padding(14)
        .frame(width: 324)
        .background(
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                if !RenderMode.isActive {
                    VisualEffectView(material: .popover, blending: .behindWindow)
                }
                LinearGradient(
                    colors: [Theme.accent.opacity(0.10), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .environment(\.locale, model.settings.language.locale)
        .preferredColorScheme(model.settings.theme.colorScheme)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Theme.brandGradient)
                    .frame(width: 32, height: 32)
                    .shadow(color: Theme.accent.opacity(0.35), radius: 8, y: 3)
                Image(systemName: statusIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Hush")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text(statusText)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            languageSwitch
        }
    }

    private var languageSwitch: some View {
        HStack(spacing: 1) {
            ForEach(AppLanguage.allCases) { language in
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        model.settings.language = language
                    }
                } label: {
                    Text(language.shortName)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(model.settings.language == language ? Theme.accent : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(
                                model.settings.language == language
                                    ? Theme.accent.opacity(0.14)
                                    : Color.clear
                            )
                        )
                }
                .buttonStyle(.plain)
                .help(language.displayName)
            }
        }
        .padding(2)
        .background(Capsule().fill(Color.primary.opacity(0.05)))
    }

    private var permissionWarning: some View {
        Button {
            model.requestAccessibility()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(Theme.amber)
                VStack(alignment: .leading, spacing: 1) {
                    Text(t("Accessibility is off", "Нет доступа Accessibility"))
                        .font(.system(size: 11.5, weight: .semibold))
                    Text(t("The shortcut cannot fire without it", "Без него хоткей не сработает"))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(9)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Theme.amber.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Theme.amber.opacity(0.28), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var modelWarning: some View {
        Button(action: onSettings) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(Theme.amber)
                VStack(alignment: .leading, spacing: 1) {
                    Text(t("Download a model", "Скачай модель"))
                        .font(.system(size: 11.5, weight: .semibold))
                    Text(t("One-time download, then fully offline", "Один раз скачать — дальше офлайн"))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(9)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Theme.amber.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Theme.amber.opacity(0.28), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(t("Last dictation", "Последняя диктовка"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !model.lastResult.isEmpty {
                    Button {
                        TextInserter.copy(model.lastResult)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                    } label: {
                        Label(
                            copied ? t("Copied", "Скопировано") : t("Copy", "Копировать"),
                            systemImage: copied ? "checkmark" : "doc.on.doc"
                        )
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(copied ? Theme.green : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if model.lastResult.isEmpty {
                Text(t(
                    "Hold the shortcut and say something. The text appears where your cursor is.",
                    "Зажми хоткей и скажи что-нибудь. Текст появится там, где курсор."
                ))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 4)
            } else {
                Text(model.lastResult)
                    .font(.system(size: 12))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            stat(value: "\(model.todayWords)", label: t("today", "сегодня"))
            Divider().frame(height: 24)
            stat(value: "\(model.totalWords)", label: t("words", "слов"))
            Divider().frame(height: 24)
            stat(value: "\(model.savedMinutes)", label: t("min saved", "мин"))
        }
        .padding(.vertical, 2)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
            Text(label)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                HStack(spacing: 6) {
                    Image(systemName: isListening ? "stop.fill" : "mic.fill")
                    Text(isListening
                         ? t("Stop & paste", "Стоп и вставить")
                         : t("Start dictation", "Начать диктовку"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())

            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(SecondaryButtonStyle())
            .help(t("Settings", "Настройки"))

            Button(action: onQuit) {
                Image(systemName: "power")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(SecondaryButtonStyle())
            .help(t("Quit Hush", "Завершить Hush"))
        }
    }

    private var isListening: Bool {
        if case .listening = model.phase { return true }
        return false
    }

    private var statusIcon: String {
        switch model.phase {
        case .listening: return "mic.fill"
        case .transcribing: return "waveform"
        case .done: return "checkmark"
        case .failed: return "exclamationmark"
        default: return "waveform"
        }
    }

    private var statusText: String {
        switch model.phase {
        case .listening: return t("Listening…", "Слушаю…")
        case .transcribing: return t("Transcribing…", "Распознаю…")
        case .done: return t("Pasted", "Вставлено")
        case .copied: return t("Copied", "Скопировано")
        case .failed(let message): return message
        case .idle:
            switch model.modelState {
            case .ready, .sleeping:
                return t(
                    "Ready · \(model.settings.hotkey.display(model.settings.language))",
                    "Готова · \(model.settings.hotkey.display(model.settings.language))"
                )
            case .loading: return t("Loading model…", "Загружаю модель…")
            default: return t("Model not installed", "Модель не установлена")
            }
        }
    }

}

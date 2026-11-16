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

    init(model: AppModel, onSettings: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.model = model
        self.onSettings = onSettings
        self.onQuit = onQuit
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Sotto")
            button.image?.isTemplate = true
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Sotto — hold Fn to dictate"
        }

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        let hosting = NSHostingController(
            rootView: MenuPopoverView(
                model: model,
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
    }

    private func updateIcon(for phase: DictationPhase) {
        let name: String
        switch phase {
        case .listening: name = "mic.fill"
        case .transcribing: name = "waveform.badge.magnifyingglass"
        case .done: name = "checkmark"
        default: name = "waveform"
        }
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Sotto")
            ?? NSImage(systemSymbolName: "waveform", accessibilityDescription: "Sotto")
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
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Sotto", action: #selector(quit), keyEquivalent: "q").target = self
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
    let onSettings: () -> Void
    let onQuit: () -> Void

    @State private var copied = false

    private var installed: Bool {
        ModelCatalog.isInstalled(model.settings.modelID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
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
                Text("Sotto")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text(statusText)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if case .listening = model.phase {
                Text(timeString(model.elapsed))
                    .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.pink)
            } else {
                Badge(text: "Local", color: Theme.green)
            }
        }
    }

    private var modelWarning: some View {
        Button(action: onSettings) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(Theme.amber)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Download a model")
                        .font(.system(size: 11.5, weight: .semibold))
                    Text("One-time download, then fully offline")
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
                Text("Last dictation")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !model.lastResult.isEmpty {
                    Button {
                        TextInserter.copy(model.lastResult)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                    } label: {
                        Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(copied ? Theme.green : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if model.lastResult.isEmpty {
                Text("Hold Fn and say something. The text appears where your cursor is.")
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
            stat(value: "\(model.todayWords)", label: "today")
            Divider().frame(height: 24)
            stat(value: "\(model.totalWords)", label: "words")
            Divider().frame(height: 24)
            stat(value: "\(model.savedMinutes)", label: "min saved")
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
            Button {
                model.toggleDictation()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isListening ? "stop.fill" : "mic.fill")
                    Text(isListening ? "Stop & paste" : "Start dictation")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())

            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(SecondaryButtonStyle())
            .help("Settings")

            Button(action: onQuit) {
                Image(systemName: "power")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(SecondaryButtonStyle())
            .help("Quit Sotto")
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
        case .listening: return "Listening…"
        case .transcribing: return "Transcribing…"
        case .done: return "Pasted"
        case .copied: return "Copied"
        case .failed(let message): return message
        case .idle:
            switch model.modelState {
            case .ready, .sleeping: return "Ready · hold Fn"
            case .loading: return "Loading model…"
            default: return "Model not installed"
            }
        }
    }

    private func timeString(_ interval: Double) -> String {
        let seconds = Int(interval.rounded())
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

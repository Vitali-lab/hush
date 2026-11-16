import AppKit
import Combine
import SwiftUI

final class HUDPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 144, height: 56),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        canHide = false
        animationBehavior = .none
    }
}

@MainActor
final class HUDController {
    private let panel: HUDPanel
    private let model: AppModel
    private var cancellables: Set<AnyCancellable> = []
    private var watchdog: Timer?

    init(model: AppModel) {
        self.model = model
        panel = HUDPanel()
        panel.contentView = NSHostingView(rootView: HUDView(model: model))

        model.$phase
            .removeDuplicates()
            .sink { [weak self] phase in
                guard let self else { return }
                Log.info("HUD phase: \(phase)")
                if case .idle = phase {
                    self.hide()
                } else {
                    self.show()
                }
            }
            .store(in: &cancellables)

        // Safety net: if the window server or a space switch drops the panel
        // while a dictation is still running, bring it back.
        watchdog = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.model.phase.isActive, !self.panel.isVisible else { return }
                self.show()
            }
        }
    }

    private func show() {
        // If the app was hidden with Cmd+H the panel would stay hidden too.
        if NSApp.isHidden {
            NSApp.unhide(nil)
        }

        guard let screen = screenUnderMouse() else { return }
        let size = panel.frame.size
        let x = screen.visibleFrame.midX - size.width / 2
        let y = screen.visibleFrame.minY + 34
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.alphaValue = 1
        panel.orderFrontRegardless()
    }

    private func hide() {
        // No alpha animation here: a fast stop/start used to leave the panel
        // half-faded and flagged as visible, so it never came back.
        panel.orderOut(nil)
    }

    private func screenUnderMouse() -> NSScreen? {
        let point = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
    }
}

struct HUDView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme

    private var stateKey: String {
        switch model.phase {
        case .idle: return "idle"
        case .listening: return "listening"
        case .transcribing: return "transcribing"
        case .done: return "done"
        case .copied: return "copied"
        case .failed: return "failed"
        }
    }

    var body: some View {
        ZStack {
            HUDPlate()

            Group {
                switch model.phase {
                case .listening:
                    Waveform(levels: Array(model.levels.suffix(24)))
                        .frame(width: 92, height: 18)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                case .transcribing:
                    PulseDots()
                        .transition(.opacity)
                case .done:
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.85))
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                case .copied:
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.8))
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                case .failed:
                    Image(systemName: "exclamationmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.75))
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                case .idle:
                    EmptyView()
                }
            }
        }
        .frame(width: 124, height: 36)
        .shadow(color: .black.opacity(scheme == .dark ? 0.35 : 0.18), radius: 8, y: 3)
        .padding(10)
        .frame(width: 144, height: 56)
        .animation(.spring(response: 0.34, dampingFraction: 0.78), value: stateKey)
        .preferredColorScheme(model.settings.theme.colorScheme)
    }
}

private struct HUDPlate: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            if !RenderMode.isActive {
                HUDEffectView(material: .popover)
            }
            Capsule()
                .fill(Color(nsColor: .windowBackgroundColor).opacity(scheme == .dark ? 0.62 : 0.72))
            LinearGradient(
                colors: [Color.white.opacity(scheme == .dark ? 0.10 : 0.28), Color.clear],
                startPoint: .top,
                endPoint: .center
            )
        }
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(
                    scheme == .dark
                        ? Color.white.opacity(0.30)
                        : Color.black.opacity(0.72),
                    lineWidth: 1.2
                )
        )
    }
}

private struct HUDEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

private struct Waveform: View {
    let levels: [Float]

    var body: some View {
        HStack(alignment: .center, spacing: 1.9) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                Capsule()
                    .fill(Color.primary.opacity(0.82))
                    .frame(width: 1.8, height: max(2, CGFloat(level) * 17))
            }
        }
        .animation(.linear(duration: 0.09), value: levels)
    }
}

private struct PulseDots: View {
    @State private var active = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.primary.opacity(0.75))
                    .frame(width: 3.2, height: 3.2)
                    .opacity(active == index ? 1 : 0.25)
                    .scaleEffect(active == index ? 1.15 : 1)
            }
        }
        .onReceive(Timer.publish(every: 0.24, on: .main, in: .common).autoconnect()) { _ in
            withAnimation(.easeInOut(duration: 0.18)) {
                active = (active + 1) % 3
            }
        }
    }
}

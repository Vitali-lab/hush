import AppKit
import Combine
import SwiftUI

final class HUDPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 192, height: 70),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        animationBehavior = .none
    }
}

@MainActor
final class HUDController {
    private let panel: HUDPanel
    private let model: AppModel
    private var cancellables: Set<AnyCancellable> = []
    private var isVisible = false

    init(model: AppModel) {
        self.model = model
        panel = HUDPanel()
        panel.contentView = NSHostingView(rootView: HUDView(model: model))

        model.$phase
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] phase in
                guard let self else { return }
                if case .idle = phase {
                    self.hide()
                } else {
                    self.show()
                }
            }
            .store(in: &cancellables)
    }

    private func show() {
        guard let screen = NSScreen.main else { return }
        let size = panel.frame.size
        let x = screen.visibleFrame.midX - size.width / 2
        let y = screen.visibleFrame.minY + 40
        panel.setFrameOrigin(NSPoint(x: x, y: y))

        if !isVisible {
            isVisible = true
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
        }
    }

    private func hide() {
        guard isVisible else { return }
        isVisible = false
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, !self.isVisible else { return }
            self.panel.orderOut(nil)
        })
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
                    Waveform(levels: Array(model.levels.suffix(30)))
                        .frame(width: 122, height: 24)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                case .transcribing:
                    PulseDots()
                        .transition(.opacity)
                case .done:
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.85))
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                case .copied:
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.8))
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                case .failed:
                    Image(systemName: "exclamationmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.75))
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                case .idle:
                    EmptyView()
                }
            }
        }
        .frame(width: 168, height: 46)
        .shadow(color: .black.opacity(scheme == .dark ? 0.35 : 0.18), radius: 10, y: 4)
        .padding(12)
        .frame(width: 192, height: 70)
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
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                Capsule()
                    .fill(Color.primary.opacity(0.82))
                    .frame(width: 2, height: max(2.5, CGFloat(level) * 22))
            }
        }
        .animation(.linear(duration: 0.09), value: levels)
    }
}

private struct PulseDots: View {
    @State private var active = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.primary.opacity(0.75))
                    .frame(width: 4, height: 4)
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

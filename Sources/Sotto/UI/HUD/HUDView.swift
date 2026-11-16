import AppKit
import Combine
import SwiftUI

final class HUDPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 114),
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
        let y = screen.visibleFrame.minY + 78
        panel.setFrameOrigin(NSPoint(x: x, y: y))

        if !isVisible {
            isVisible = true
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
        }
    }

    private func hide() {
        guard isVisible else { return }
        isVisible = false
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel.orderOut(nil)
        })
    }
}

struct HUDView: View {
    @ObservedObject var model: AppModel

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
        HStack(spacing: 13) {
            StatusOrb(phase: model.phase)

            Group {
                switch model.phase {
                case .listening:
                    listeningContent
                case .transcribing:
                    processingContent
                case .done(let text):
                    resultContent(text: text, copied: false)
                case .copied(let text):
                    resultContent(text: text, copied: true)
                case .failed(let message):
                    failureContent(message)
                case .idle:
                    Text("Ready")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
        .padding(.leading, 14)
        .padding(.trailing, 16)
        .frame(width: 380, height: 74)
        .background(HUDBackground())
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.28), radius: 22, y: 10)
        .shadow(color: Theme.accent.opacity(0.12), radius: 30, y: 2)
        .padding(20)
        .frame(width: 420, height: 114)
        .animation(.easeOut(duration: 0.18), value: stateKey)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: model.phase)
    }

    // MARK: - Content

    private var listeningContent: some View {
        HStack(spacing: 10) {
            Waveform(levels: Array(model.levels.suffix(30)))
                .frame(width: 130, height: 30)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .leading)))

            Text("Listening")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize()
        }
    }

    private var processingContent: some View {
        HStack(spacing: 9) {
            Text("Transcribing")
                .font(.system(size: 12.5, weight: .medium))
            ShimmerDots()
        }
    }

    private func resultContent(text: String, copied: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(copied ? "Copied to clipboard" : "Pasted at cursor")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(copied ? Theme.pink : Theme.green)
            Text(text)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.primary.opacity(0.9))
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func failureContent(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Nothing to paste")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Theme.amber)
            Text(message)
                .font(.system(size: 12))
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch model.phase {
        case .listening:
            HStack(spacing: 10) {
                Text(timeString(model.elapsed))
                    .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)
                KeyCap(text: "esc")
                    .opacity(0.7)
            }
            .transition(.opacity)
        case .transcribing:
            Spinner()
                .transition(.opacity)
        case .copied:
            KeyCap(text: "⌘V")
                .transition(.opacity)
        default:
            EmptyView()
        }
    }

    private func timeString(_ interval: Double) -> String {
        let seconds = Int(interval.rounded())
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct HUDBackground: View {
    var body: some View {
        ZStack {
            Capsule().fill(Color(nsColor: .windowBackgroundColor).opacity(0.96))
            if !RenderMode.isActive {
                HUDEffectView()
            }
            LinearGradient(
                colors: [Color.white.opacity(0.10), Color.clear],
                startPoint: .top,
                endPoint: .center
            )
        }
        .clipShape(Capsule())
    }
}

private struct HUDEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

private struct StatusOrb: View {
    let phase: DictationPhase
    @State private var pulse = false

    private var color: Color {
        switch phase {
        case .idle: return .secondary
        case .listening: return Theme.pink
        case .transcribing: return Theme.amber
        case .done: return Theme.green
        case .copied: return Theme.pink
        case .failed: return Theme.danger
        }
    }

    private var gradient: LinearGradient {
        switch phase {
        case .listening:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.42, blue: 0.55), Color(red: 0.95, green: 0.26, blue: 0.42)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .transcribing:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.72, blue: 0.36), Color(red: 0.97, green: 0.55, blue: 0.20)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .done:
            return LinearGradient(colors: [Color(red: 0.38, green: 0.87, blue: 0.55), Color(red: 0.20, green: 0.74, blue: 0.44)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .copied:
            return LinearGradient(colors: [Color(red: 0.86, green: 0.45, blue: 1.0), Color(red: 0.60, green: 0.33, blue: 0.98)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .failed:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.48, blue: 0.48), Color(red: 0.92, green: 0.28, blue: 0.33)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .idle:
            return LinearGradient(colors: [Color.secondary, Color.secondary], startPoint: .top, endPoint: .bottom)
        }
    }

    private var isTinted: Bool {
        if case .idle = phase { return false }
        return true
    }

    private var icon: String {
        switch phase {
        case .idle: return "waveform"
        case .listening: return "mic.fill"
        case .transcribing: return "waveform"
        case .done: return "checkmark"
        case .copied: return "doc.on.clipboard"
        case .failed: return "exclamationmark"
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.16))
                .frame(width: 34, height: 34)

            if isTinted {
                Circle()
                    .fill(gradient)
                    .frame(width: 34, height: 34)
                    .shadow(color: color.opacity(0.45), radius: 8, y: 2)
            }

            Circle()
                .fill(color.opacity(0.30))
                .frame(width: 34, height: 34)
                .scaleEffect(pulse ? 1.35 : 1)
                .opacity(pulse ? 0 : 1)

            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isTinted ? Color.white : color)
        }
        .onAppear { startPulse() }
        .onChange(of: phase) { _, _ in startPulse() }
        .animation(.easeOut(duration: 0.3), value: phase)
    }

    private func startPulse() {
        pulse = false
        guard case .listening = phase else { return }
        withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
            pulse = true
        }
    }
}

private struct Waveform: View {
    let levels: [Float]

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Theme.accentBright, Theme.pink.opacity(0.9)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 2.4, height: max(3, CGFloat(level) * 28))
                    .opacity(0.4 + Double(min(level * 1.4, 0.6)))
            }
        }
        .animation(.linear(duration: 0.09), value: levels)
    }
}

private struct Spinner: View {
    @State private var spinning = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(Theme.amber, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: 14, height: 14)
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: spinning)
            .onAppear { spinning = true }
    }
}

private struct ShimmerDots: View {
    @State private var active = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Theme.amber)
                    .frame(width: 4, height: 4)
                    .opacity(active == index ? 1 : 0.25)
            }
        }
        .onReceive(Timer.publish(every: 0.26, on: .main, in: .common).autoconnect()) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                active = (active + 1) % 3
            }
        }
    }
}

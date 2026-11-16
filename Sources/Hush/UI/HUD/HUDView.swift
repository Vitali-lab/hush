import AppKit
import Combine
import SwiftUI

final class HUDPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 296, height: 88),
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
        let y = screen.visibleFrame.minY + 54
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
            self?.panel.orderOut(nil)
        })
    }
}

struct HUDView: View {
    @ObservedObject var model: AppModel

    private var t: Loc { Loc(model.settings.language) }

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
        HStack(spacing: 9) {
            StatusOrb(phase: model.phase, size: 26)

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
                    Text(t("Ready", "Готово"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
        .padding(.horizontal, 12)
        .frame(width: 264, height: 56)
        .background(HUDBackground())
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.20), Color.white.opacity(0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.24), radius: 14, y: 6)
        .shadow(color: Theme.accent.opacity(0.10), radius: 20, y: 2)
        .padding(16)
        .frame(width: 296, height: 88)
        .animation(.easeOut(duration: 0.16), value: stateKey)
        .animation(.spring(response: 0.36, dampingFraction: 0.78), value: model.phase)
        .preferredColorScheme(model.settings.theme.colorScheme)
    }

    // MARK: - Content

    private var listeningContent: some View {
        HStack(spacing: 8) {
            Waveform(levels: Array(model.levels.suffix(26)))
                .frame(width: 86, height: 24)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .leading)))
        }
    }

    private var processingContent: some View {
        HStack(spacing: 6) {
            Text(t("Transcribing", "Распознаю"))
                .font(.system(size: 11.5, weight: .medium))
                .lineLimit(1)
            ShimmerDots()
        }
    }

    private func resultContent(text: String, copied: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(copied
                 ? t("Copied", "Скопировано")
                 : t("Pasted", "Вставлено"))
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(copied ? Theme.pink : Theme.green)
            Text(text)
                .font(.system(size: 11.5))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.primary.opacity(0.9))
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func failureContent(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(t("Nothing to paste", "Нечего вставить"))
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(Theme.amber)
            Text(message)
                .font(.system(size: 11.5))
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch model.phase {
        case .listening:
            HStack(spacing: 7) {
                Text(timeString(model.elapsed))
                    .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)
                HUDHint(text: "esc")
            }
            .transition(.opacity)
        case .transcribing:
            Spinner()
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

private struct HUDHint: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 8.5, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 1.5)
            .background(
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(Color.primary.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
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
    var size: CGFloat = 30
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
                .frame(width: size, height: size)

            if isTinted {
                Circle()
                    .fill(gradient)
                    .frame(width: size, height: size)
                    .shadow(color: color.opacity(0.45), radius: 6, y: 2)
            }

            Circle()
                .fill(color.opacity(0.30))
                .frame(width: size, height: size)
                .scaleEffect(pulse ? 1.4 : 1)
                .opacity(pulse ? 0 : 1)

            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(isTinted ? Color.white : color)
        }
        .onAppear { startPulse() }
        .onChange(of: phase) { _, _ in startPulse() }
        .animation(.easeOut(duration: 0.3), value: phase)
    }

    private func startPulse() {
        pulse = false
        guard case .listening = phase else { return }
        withAnimation(.easeOut(duration: 1.05).repeatForever(autoreverses: false)) {
            pulse = true
        }
    }
}

private struct Waveform: View {
    let levels: [Float]

    var body: some View {
        HStack(alignment: .center, spacing: 1.7) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Theme.accentBright, Theme.pink.opacity(0.9)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 2, height: max(2.5, CGFloat(level) * 22))
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
            .stroke(Theme.amber, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            .frame(width: 12, height: 12)
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: spinning)
            .onAppear { spinning = true }
    }
}

private struct ShimmerDots: View {
    @State private var active = 0

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Theme.amber)
                    .frame(width: 3.5, height: 3.5)
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

import AppKit
import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case model
    case dictionary
    case history
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .model: return "Model"
        case .dictionary: return "Words"
        case .history: return "History"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .model: return "cpu"
        case .dictionary: return "text.book.closed"
        case .history: return "clock.arrow.circlepath"
        case .about: return "sparkles"
        }
    }
}

final class SettingsWindowController: NSWindowController {
    private let model: AppModel

    init(model: AppModel) {
        self.model = model

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 880, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Sotto"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 780, height: 560)
        window.backgroundColor = .windowBackgroundColor
        window.center()
        window.contentView = NSHostingView(rootView: SettingsRootView(model: model))
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsRootView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme
    @State private var tab: SettingsTab = .general

    init(model: AppModel, initialTab: SettingsTab = .general) {
        self.model = model
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(model: model, selection: $tab)
                .frame(width: 212)

            Rectangle()
                .fill(Theme.cardStroke(scheme))
                .frame(width: 1)
                .ignoresSafeArea()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(SettingsBackground())
        .frame(minWidth: 780, minHeight: 560)
    }

    @ViewBuilder
    private var content: some View {
        if RenderMode.isActive {
            VStack(spacing: 0) {
                contentBody
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            ScrollView {
                contentBody
            }
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.top)
        }
    }

    private var contentBody: some View {
        Group {
            switch tab {
            case .general:
                GeneralView(model: model, tab: $tab)
            case .model:
                ModelsView(model: model)
            case .dictionary:
                DictionaryView(model: model)
            case .history:
                HistoryView(model: model)
            case .about:
                AboutView()
            }
        }
        .padding(.horizontal, 30)
        .padding(.top, 34)
        .padding(.bottom, 30)
        .frame(maxWidth: 640, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeOut(duration: 0.16), value: tab)
        .id(tab)
        .transition(.opacity)
    }
}

private struct Sidebar: View {
    @ObservedObject var model: AppModel
    @Binding var selection: SettingsTab
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                BrandMark(size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Sotto")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text("local dictation")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 46)
            .padding(.horizontal, 18)
            .padding(.bottom, 22)

            VStack(spacing: 3) {
                ForEach(SettingsTab.allCases) { item in
                    SidebarItem(
                        item: item,
                        isSelected: selection == item
                    ) {
                        withAnimation(.snappy(duration: 0.22)) {
                            selection = item
                        }
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            statusFooter
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
    }

    private var statusFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                    .shadow(color: statusColor.opacity(0.6), radius: 3)
                Text(statusText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text("v\(AppInfo.version)")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary.opacity(0.7))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(radius: 12)
    }

    private var statusColor: Color {
        switch model.modelState {
        case .ready, .sleeping: return Theme.green
        case .loading: return Theme.amber
        case .notInstalled, .failed: return Theme.danger
        }
    }

    private var statusText: String {
        switch model.modelState {
        case .ready: return "Model ready"
        case .sleeping: return "Model on disk"
        case .loading: return "Loading model…"
        case .notInstalled: return "Model not installed"
        case .failed: return "Model error"
        }
    }
}

private struct SidebarItem: View {
    let item: SettingsTab
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(.system(size: 12.5, weight: .medium))
                    .frame(width: 18)
                Text(item.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? Theme.accent : Color.primary.opacity(0.78))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? Theme.accent.opacity(0.12) : (hovering ? Color.primary.opacity(0.04) : .clear))
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.13), value: hovering)
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

struct BrandMark: View {
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(Theme.brandGradient)
            Image(systemName: "waveform")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: Theme.accent.opacity(0.35), radius: size * 0.22, y: size * 0.1)
    }
}

struct SettingsBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            if !RenderMode.isActive {
                VisualEffectView(material: .underWindowBackground, blending: .behindWindow)
            }
            LinearGradient(
                colors: [
                    Theme.accent.opacity(scheme == .dark ? 0.16 : 0.09),
                    Color.clear,
                    Theme.pink.opacity(scheme == .dark ? 0.08 : 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blending
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blending
    }
}

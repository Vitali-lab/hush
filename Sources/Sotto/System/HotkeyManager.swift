import AppKit

@MainActor
final class HotkeyManager {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    var onToggle: (() -> Void)?
    var onCancel: (() -> Void)?

    var choice: HotkeyChoice = .fnHold

    var isListening: (() -> Bool)?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var fnIsDown = false
    private var rightOptionIsDown = false
    private var lastFnTap: Date?

    func start() {
        stop()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.flagsChanged, .keyDown]
        ) { [weak self] event in
            DispatchQueue.main.async {
                self?.handle(event)
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.flagsChanged, .keyDown]
        ) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil
        fnIsDown = false
        rightOptionIsDown = false
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .flagsChanged:
            handleFlags(event)
        case .keyDown:
            handleKeyDown(event)
        default:
            break
        }
    }

    private func handleFlags(_ event: NSEvent) {
        let flags = event.modifierFlags
        let fnDown = flags.contains(.function)
        if fnDown != fnIsDown {
            fnIsDown = fnDown
            switch choice {
            case .fnHold:
                fnDown ? onPress?() : onRelease?()
            case .fnDoubleTap:
                if fnDown { registerFnTap() }
            default:
                break
            }
        }

        if event.keyCode == 61 {
            let optionDown = flags.contains(.option)
            if optionDown != rightOptionIsDown {
                rightOptionIsDown = optionDown
                if choice == .rightOptionHold {
                    optionDown ? onPress?() : onRelease?()
                }
            }
        }
    }

    private func registerFnTap() {
        let now = Date()
        if let last = lastFnTap, now.timeIntervalSince(last) < 0.45 {
            lastFnTap = nil
            onToggle?()
        } else {
            lastFnTap = now
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        if event.keyCode == 53 { // Escape
            if isListening?() == true {
                onCancel?()
            }
            return
        }

        guard !event.isARepeat else { return }

        if choice == .controlOptionSpace,
           event.keyCode == 49,
           event.modifierFlags.contains(.control),
           event.modifierFlags.contains(.option) {
            onToggle?()
        }
    }
}

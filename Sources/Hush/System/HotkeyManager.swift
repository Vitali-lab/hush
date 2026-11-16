import AppKit

@MainActor
final class HotkeyManager {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    var onToggle: (() -> Void)?
    var onCancel: (() -> Void)?

    var binding: HotkeyBinding = .defaultBinding {
        didSet {
            if binding != oldValue {
                resetState()
            }
        }
    }

    var isListening: (() -> Bool)?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var modifierIsDown = false
    private var comboIsDown = false
    private var lastFnTap: Date?

    func start() {
        stop()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.flagsChanged, .keyDown, .keyUp]
        ) { [weak self] event in
            DispatchQueue.main.async {
                self?.handle(event)
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.flagsChanged, .keyDown, .keyUp]
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
        resetState()
    }

    private func resetState() {
        modifierIsDown = false
        comboIsDown = false
        lastFnTap = nil
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .flagsChanged:
            handleFlags(event)
        case .keyDown:
            handleKeyDown(event)
        case .keyUp:
            handleKeyUp(event)
        default:
            break
        }
    }

    private func handleFlags(_ event: NSEvent) {
        if binding.doubleTap, binding.keyCode == 63 {
            let fnDown = event.modifierFlags.contains(.function)
            if fnDown, !modifierIsDown {
                modifierIsDown = true
                registerFnTap()
            } else if !fnDown {
                modifierIsDown = false
            }
            return
        }

        guard binding.isModifierOnly, binding.keyCode == event.keyCode else { return }

        let isDown = binding.modifierIsDown(event.modifierFlags)
        guard isDown != modifierIsDown else { return }
        modifierIsDown = isDown

        if binding.mode == .hold {
            isDown ? onPress?() : onRelease?()
        } else if isDown {
            onToggle?()
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        if event.keyCode == 53 { // Escape
            if isListening?() == true {
                onCancel?()
            }
            return
        }

        guard !binding.isModifierOnly, !binding.doubleTap else { return }
        guard !event.isARepeat else { return }
        guard binding.matches(keyCode: event.keyCode, flags: event.modifierFlags) else { return }

        switch binding.mode {
        case .hold:
            guard !comboIsDown else { return }
            comboIsDown = true
            onPress?()
        case .toggle:
            onToggle?()
        }
    }

    private func handleKeyUp(_ event: NSEvent) {
        guard binding.mode == .hold, !binding.isModifierOnly else { return }
        guard comboIsDown, event.keyCode == binding.keyCode else { return }
        comboIsDown = false
        onRelease?()
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
}

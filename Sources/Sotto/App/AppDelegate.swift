import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel.shared
    private var hud: HUDController?
    private var menuBar: MenuBarController?
    private var settingsWindow: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildMainMenu()

        settingsWindow = SettingsWindowController(model: model)
        hud = HUDController(model: model)
        menuBar = MenuBarController(
            model: model,
            onSettings: { [weak self] in self?.openSettings() },
            onQuit: { NSApp.terminate(nil) }
        )
        model.requestSettings = { [weak self] in self?.openSettings() }

        model.start()

        let isFreshInstall = !model.settings.hasCompletedSetup
        let hasModel = ModelCatalog.isInstalled(model.settings.modelID)
        let needsPermissions = !model.isMicrophoneGranted || !model.isAccessibilityGranted
        if isFreshInstall || !hasModel || needsPermissions {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.openSettings()
            }
        }

        if let flagIndex = CommandLine.arguments.firstIndex(of: "--capture-ui"),
           CommandLine.arguments.count > flagIndex + 1 {
            let directory = CommandLine.arguments[flagIndex + 1]
            model.setModelStateForPreview(.ready)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.openSettings()
                self?.model.setPhaseForPreview(.listening, levels: (0..<42).map { index in
                    Float(0.2 + 0.7 * abs(sin(Double(index) / 5.5)))
                })
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                WindowCapture.captureAllWindows(to: directory)
                NSApp.terminate(nil)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { openSettings() }
        return true
    }

    @objc private func openSettings() {
        settingsWindow?.show()
    }

    @objc private func showAbout() {
        openSettings()
    }

    private func buildMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Sotto", action: #selector(showAbout), keyEquivalent: "").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Hide Sotto",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        appMenu.addItem(
            withTitle: "Quit Sotto",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }
}

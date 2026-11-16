import AppKit
import SwiftUI

@MainActor
enum UIPreview {
    static func renderAll(to directoryPath: String) {
        let directory = URL(fileURLWithPath: directoryPath, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let model = AppModel.shared
        let settingsSize = CGSize(width: 880, height: 1200)

        render(SettingsRootView(model: model), size: settingsSize, name: "settings-general", in: directory)
        render(SettingsRootView(model: model, initialTab: .model), size: settingsSize, name: "settings-model", in: directory)
        render(SettingsRootView(model: model, initialTab: .history), size: settingsSize, name: "settings-history", in: directory)

        model.setModelStateForPreview(.ready)
        model.setPhaseForPreview(.listening, levels: sampleLevels())
        render(HUDView(model: model), size: CGSize(width: 420, height: 114), name: "hud-listening", in: directory)

        model.setPhaseForPreview(.transcribing)
        render(HUDView(model: model), size: CGSize(width: 420, height: 114), name: "hud-transcribing", in: directory)

        model.setPhaseForPreview(.done("Привет, это тест локальной диктовки на Mac."))
        render(HUDView(model: model), size: CGSize(width: 420, height: 114), name: "hud-done", in: directory)

        model.setPhaseForPreview(.idle)
        render(MenuPopoverView(model: model, onSettings: {}, onQuit: {}), size: CGSize(width: 324, height: 330), name: "menu", in: directory)

        print("Rendered previews to \(directory.path)")
    }

    private static func render<V: View>(_ view: V, size: CGSize, name: String, in directory: URL) {
        let renderer = ImageRenderer(
            content: view
                .frame(width: size.width, height: size.height)
                .background(Color(nsColor: .windowBackgroundColor))
        )
        renderer.scale = 2

        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else {
            print("Failed to render \(name)")
            return
        }

        try? data.write(to: directory.appendingPathComponent("\(name).png"))
    }

    private static func sampleLevels() -> [Float] {
        (0..<42).map { index in
            let phase = Double(index) / 6.0
            let value = 0.25 + 0.65 * abs(sin(phase)) * abs(cos(phase * 0.7))
            return Float(value)
        }
    }
}

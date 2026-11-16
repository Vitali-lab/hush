import AppKit
import Foundation

enum WindowCapture {
    static func captureAllWindows(to directoryPath: String) {
        let directory = URL(fileURLWithPath: directoryPath, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var index = 0
        for window in NSApp.windows where window.isVisible && window.frame.width > 40 {
            let windowID = CGWindowID(window.windowNumber)

            if let cgImage = CGWindowListCreateImage(
                .null,
                .optionIncludingWindow,
                windowID,
                [.boundsIgnoreFraming, .bestResolution]
            ) {
                let rep = NSBitmapImageRep(cgImage: cgImage)
                if let data = rep.representation(using: .png, properties: [:]) {
                    let name = window is NSPanel ? "panel-\(index)" : "window-\(index)"
                    try? data.write(to: directory.appendingPathComponent("\(name).png"))
                    index += 1
                    continue
                }
            }

            guard let view = window.contentView else { continue }
            let bounds = view.bounds
            guard bounds.width > 0, bounds.height > 0,
                  let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else { continue }

            view.cacheDisplay(in: bounds, to: rep)

            guard let data = rep.representation(using: .png, properties: [:]) else { continue }
            let name = window is NSPanel ? "panel-\(index)" : "window-\(index)"
            try? data.write(to: directory.appendingPathComponent("\(name).png"))
            index += 1
        }
    }
}

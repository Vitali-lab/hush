import AppKit
import CoreGraphics
import Foundation

let size = 1024.0
let scale = size / 1024.0

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil,
    width: Int(size),
    height: Int(size),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Could not create context")
}

context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)

// Background squircle
let inset = 44.0
let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let radius = 228.0
let background = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

context.saveGState()
context.addPath(background)
context.clip()

let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [
        CGColor(red: 0.40, green: 0.31, blue: 0.98, alpha: 1),
        CGColor(red: 0.52, green: 0.35, blue: 0.99, alpha: 1),
        CGColor(red: 0.82, green: 0.36, blue: 0.86, alpha: 1)
    ] as CFArray,
    locations: [0, 0.55, 1]
)!
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: rect.minX, y: rect.maxY),
    end: CGPoint(x: rect.maxX, y: rect.minY),
    options: []
)

// Soft top-left light
let highlight = CGGradient(
    colorsSpace: colorSpace,
    colors: [
        CGColor(gray: 1, alpha: 0.22),
        CGColor(gray: 1, alpha: 0)
    ] as CFArray,
    locations: [0, 1]
)!
context.drawRadialGradient(
    highlight,
    startCenter: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.maxY - rect.height * 0.12),
    startRadius: 0,
    endCenter: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.maxY - rect.height * 0.12),
    endRadius: rect.width * 0.75,
    options: []
)
context.restoreGState()

// Inner edge
context.addPath(background)
context.setStrokeColor(CGColor(gray: 1, alpha: 0.18))
context.setLineWidth(3)
context.strokePath()

// Waveform
let barWidth = 42.0 * scale
let gap = 25.0 * scale
let heights: [CGFloat] = [0.26, 0.46, 0.68, 0.92, 1.0, 0.74, 0.44]
let totalWidth = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * gap
var x = (size - totalWidth) / 2
let centerY = size / 2
let maxHeight = 320.0 * scale

context.setShadow(
    offset: CGSize(width: 0, height: -8),
    blur: 24,
    color: CGColor(red: 0.10, green: 0.05, blue: 0.3, alpha: 0.28)
)

for (index, factor) in heights.enumerated() {
    let height = max(barWidth, maxHeight * factor)
    let barRect = CGRect(x: x, y: centerY - height / 2, width: barWidth, height: height)
    let path = CGPath(
        roundedRect: barRect,
        cornerWidth: barWidth / 2,
        cornerHeight: barWidth / 2,
        transform: nil
    )
    let alpha: CGFloat = index == 4 ? 1.0 : 0.88
    context.addPath(path)
    context.setFillColor(CGColor(gray: 1, alpha: alpha))
    context.fillPath()
    x += barWidth + gap
}

guard let image = context.makeImage() else {
    fatalError("Could not render image")
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon-1024.png")

let rep = NSBitmapImageRep(cgImage: image)
guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode png")
}
try png.write(to: outputURL)
print(outputURL.path)

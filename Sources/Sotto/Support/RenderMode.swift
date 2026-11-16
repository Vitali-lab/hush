import Foundation

enum RenderMode {
    static let isActive = CommandLine.arguments.contains("--render-ui")
}

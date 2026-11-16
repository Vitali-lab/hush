import AppKit
import AVFoundation
import ApplicationServices

enum Permissions {
    enum Microphone {
        static var status: AVAuthorizationStatus {
            AVCaptureDevice.authorizationStatus(for: .audio)
        }

        static var isGranted: Bool { status == .authorized }

        static func request() async -> Bool {
            switch status {
            case .authorized:
                return true
            case .notDetermined:
                return await AVCaptureDevice.requestAccess(for: .audio)
            default:
                return false
            }
        }
    }

    static var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    static var isMicrophoneGranted: Bool {
        Microphone.isGranted
    }

    @discardableResult
    static func promptAccessibility() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func openPrivacyPane(_ pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
        NSWorkspace.shared.open(url)
    }
}

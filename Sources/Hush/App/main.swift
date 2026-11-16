import AppKit

if CommandLine.arguments.contains("--selftest") {
    SelfTest.run()
    exit(0)
}

if let flagIndex = CommandLine.arguments.firstIndex(of: "--play-sound"),
   CommandLine.arguments.count > flagIndex + 1 {
    MainActor.assumeIsolated {
        let sound = FeedbackSound(rawValue: CommandLine.arguments[flagIndex + 1]) ?? .chime
        FeedbackSoundPlayer.shared.play(sound)
        RunLoop.main.run(until: Date().addingTimeInterval(1.2))
        exit(0)
    }
}

if let flagIndex = CommandLine.arguments.firstIndex(of: "--transcribe"),
   CommandLine.arguments.count > flagIndex + 1 {
    let path = CommandLine.arguments[flagIndex + 1]
    Task.detached {
        do {
            let text = try await TranscribeCLI.run(audioPath: path)
            print(text)
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
    dispatchMain()
}

MainActor.assumeIsolated {
    let devFlags = ["--render-ui", "--capture-ui", "--capture-menu"]
    if !devFlags.contains(where: CommandLine.arguments.contains),
       let bundleID = Bundle.main.bundleIdentifier {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        if let other = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID)
            .first(where: { $0.processIdentifier != currentPID }) {
            other.activate(options: [.activateIgnoringOtherApps])
            exit(0)
        }
    }

    let application = NSApplication.shared
    let appDelegate = AppDelegate()
    application.delegate = appDelegate
    application.setActivationPolicy(.accessory)

    if let flagIndex = CommandLine.arguments.firstIndex(of: "--render-ui"),
       CommandLine.arguments.count > flagIndex + 1 {
        UIPreview.renderAll(to: CommandLine.arguments[flagIndex + 1])
        exit(0)
    }

    application.run()
}

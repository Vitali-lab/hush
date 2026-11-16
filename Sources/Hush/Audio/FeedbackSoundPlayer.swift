import AVFoundation
import Foundation

/// Small output-only engine for the dictation cues. The sounds are generated
/// as PCM buffers at runtime, so the app ships no audio assets.
@MainActor
final class FeedbackSoundPlayer {
    static let shared = FeedbackSoundPlayer()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private var buffers: [FeedbackSound: AVAudioPCMBuffer] = [:]
    private var isConfigured = false

    private init() {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1) else {
            fatalError("Could not create the feedback audio format")
        }
        self.format = format
    }

    func play(_ sound: FeedbackSound, volume: Float = 0.22) {
        configureIfNeeded()

        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                Log.error("Feedback audio failed: \(error.localizedDescription)")
                return
            }
        }

        guard let buffer = buffers[sound] ?? makeBuffer(for: sound) else { return }
        buffers[sound] = buffer

        player.volume = volume
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        player.play()
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.prepare()
        isConfigured = true
    }

    // MARK: - Sound design

    private func makeBuffer(for sound: FeedbackSound) -> AVAudioPCMBuffer? {
        let duration: Double
        switch sound {
        case .chime: duration = 0.70
        case .bloom: duration = 0.34
        case .pluck: duration = 0.30
        case .tick: duration = 0.07
        }

        let frames = AVAudioFrameCount(max(1, duration * format.sampleRate))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0] else {
            return nil
        }
        buffer.frameLength = frames

        for frame in 0..<Int(frames) {
            let time = Double(frame) / format.sampleRate
            channel[frame] = Float(sample(for: sound, at: time))
        }
        return buffer
    }

    private func sample(for sound: FeedbackSound, at time: Double) -> Double {
        let twoPi = 2 * Double.pi

        switch sound {
        case .chime:
            let attack = min(1, time / 0.006)
            let envelope = exp(-time * 6.5) * attack
            let fundamental = sin(twoPi * 880 * time)
            let fifth = sin(twoPi * 1_318.51 * time)
            let octave = sin(twoPi * 1_760 * time)
            return (0.55 * fundamental + 0.22 * fifth + 0.10 * octave) * envelope

        case .bloom:
            let attack = min(1, time / 0.008)
            let envelope = exp(-time * 9) * attack
            let phase = twoPi * (520 * time + 190 * time * time)
            let body = sin(phase) + 0.18 * sin(2 * phase)
            return 0.55 * body * envelope

        case .pluck:
            let attack = min(1, time / 0.003)
            let envelope = exp(-time * 19) * attack
            let fundamental = sin(twoPi * 440 * time)
            let second = sin(twoPi * 880 * time)
            let third = sin(twoPi * 1_320 * time)
            return (0.5 * fundamental + 0.25 * second + 0.12 * third) * envelope

        case .tick:
            let envelope = exp(-time * 150)
            let click = sin(twoPi * 1_900 * time) * 0.28
            let noise = Double.random(in: -1...1) * 0.18
            return (click + noise) * envelope
        }
    }
}

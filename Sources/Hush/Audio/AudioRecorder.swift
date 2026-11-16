import AVFoundation

final class AudioRecorder {
    enum RecorderError: LocalizedError {
        case noInput
        case engineFailed(String)
        case converterFailed

        var errorDescription: String? {
            switch self {
            case .noInput: return "No microphone input was found."
            case .engineFailed(let reason): return "Audio engine failed: \(reason)"
            case .converterFailed: return "Could not convert the microphone stream."
            }
        }
    }

    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var samples: [Float] = []
    private var converter: AVAudioConverter?
    private var targetFormat: AVAudioFormat?
    private var running = false
    private var lastLevelTime: CFAbsoluteTime = 0

    var onLevel: ((Float) -> Void)?

    var isRunning: Bool {
        lock.lock(); defer { lock.unlock() }
        return running
    }

    func start() throws {
        if isRunning { return }

        samples.removeAll(keepingCapacity: true)

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw RecorderError.noInput
        }
        guard let target = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ), let converter = AVAudioConverter(from: inputFormat, to: target) else {
            throw RecorderError.converterFailed
        }

        self.converter = converter
        self.targetFormat = target

        input.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
            self?.consume(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw RecorderError.engineFailed(error.localizedDescription)
        }

        lock.lock()
        running = true
        lock.unlock()
    }

    func stop() -> [Float] {
        guard isRunning else { return [] }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        lock.lock()
        running = false
        let result = samples
        samples.removeAll(keepingCapacity: false)
        lock.unlock()

        converter = nil
        targetFormat = nil
        return result
    }

    func cancel() {
        _ = stop()
    }

    private func consume(_ buffer: AVAudioPCMBuffer) {
        guard let converter, let targetFormat else { return }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 128
        guard let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
            return
        }

        var supplied = false
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, outStatus in
            if supplied {
                outStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard status == .haveData || status == .inputRanDry,
              let channel = output.floatChannelData?[0] else {
            return
        }

        let count = Int(output.frameLength)
        guard count > 0 else { return }

        var energy: Float = 0
        for index in 0..<count {
            let value = channel[index]
            energy += value * value
        }

        lock.lock()
        samples.append(contentsOf: UnsafeBufferPointer(start: channel, count: count))
        lock.unlock()

        let rms = sqrt(energy / Float(count))
        let decibels = 20 * log10(max(rms, 0.00001))
        let normalized = min(1, max(0, (decibels + 55) / 55))

        let now = CFAbsoluteTimeGetCurrent()
        if now - lastLevelTime > 0.045 {
            lastLevelTime = now
            onLevel?(normalized)
        }
    }
}

@preconcurrency import WhisperKit
import Foundation

@MainActor
final class TranscriptionService {
    enum ServiceError: LocalizedError {
        case modelMissing
        case emptyAudio
        case noSpeech

        var errorDescription: String? {
            switch self {
            case .modelMissing: return "The speech model is not downloaded yet."
            case .emptyAudio: return "Nothing was recorded."
            case .noSpeech: return "No speech detected."
            }
        }
    }

    private var pipe: WhisperKit?
    private var loadedModelID: String?

    var isLoaded: Bool { pipe != nil }

    func loadModel(_ id: String) async throws {
        if loadedModelID == id, pipe != nil { return }

        guard let folder = ModelCatalog.modelFolder(for: id) else {
            throw ServiceError.modelMissing
        }

        if pipe != nil {
            unload()
        }

        let config = WhisperKitConfig(
            model: id,
            downloadBase: AppPaths.models,
            modelFolder: folder.path,
            verbose: false,
            logLevel: .none,
            prewarm: true,
            load: true,
            download: false
        )

        let started = CFAbsoluteTimeGetCurrent()
        pipe = try await WhisperKit(config)
        loadedModelID = id
        let elapsed = CFAbsoluteTimeGetCurrent() - started
        Log.info("Model \(id) loaded in \(String(format: "%.2f", elapsed))s")
    }

    func unload() {
        let oldPipe = pipe
        pipe = nil
        loadedModelID = nil
        Task {
            await oldPipe?.unloadModels()
        }
    }

    func transcribe(samples: [Float], language: String) async throws -> String {
        guard !samples.isEmpty else { throw ServiceError.emptyAudio }
        guard let pipe else { throw ServiceError.modelMissing }

        let options = DecodingOptions(
            task: .transcribe,
            language: language,
            temperature: 0,
            temperatureFallbackCount: 3,
            sampleLength: 224,
            topK: 5,
            usePrefillPrompt: true,
            usePrefillCache: true,
            detectLanguage: false,
            skipSpecialTokens: true,
            withoutTimestamps: true,
            noSpeechThreshold: 0.6
        )

        let results = await pipe.transcribe(audioArrays: [samples], decodeOptions: options)
        guard let segments = results.first ?? nil else {
            throw ServiceError.noSpeech
        }

        let text = segments.map(\.text).joined(separator: " ")
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { throw ServiceError.noSpeech }
        return cleaned
    }
}

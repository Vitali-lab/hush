import Foundation
import WhisperKit

enum TranscribeCLI {
    static func run(audioPath: String) async throws -> String {
        let modelID = ModelCatalog.defaultID

        var folder = ModelCatalog.modelFolder(for: modelID)
        if folder == nil {
            Log.info("Downloading \(modelID)…")
            folder = try await WhisperKit.download(variant: modelID, downloadBase: AppPaths.models) { progress in
                let percent = Int(progress.fractionCompleted * 100)
                FileHandle.standardError.write(Data("\r\(percent)%".utf8))
            }
            FileHandle.standardError.write(Data("\n".utf8))
        }

        guard let folder else {
            throw NSError(domain: "Hush", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Model folder not found"
            ])
        }

        let pipe = try await WhisperKit(
            WhisperKitConfig(
                model: modelID,
                downloadBase: AppPaths.models,
                modelFolder: folder.path,
                verbose: false,
                logLevel: .none,
                prewarm: false,
                load: true,
                download: false
            )
        )

        let options = DecodingOptions(
            task: .transcribe,
            language: nil,
            temperature: 0,
            usePrefillPrompt: true,
            usePrefillCache: true,
            detectLanguage: true,
            skipSpecialTokens: true,
            withoutTimestamps: true
        )

        let results = await pipe.transcribe(audioPaths: [audioPath], decodeOptions: options)
        guard let segments = results.first ?? nil else {
            throw NSError(domain: "Hush", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Empty transcription"
            ])
        }
        return segments.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

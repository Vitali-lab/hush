import Foundation

struct ModelSpec: Identifiable, Hashable {
    let id: String
    let englishName: String
    let russianName: String
    let englishDetail: String
    let russianDetail: String
    let sizeMB: Int
    let speed: Int
    let accuracy: Int
    let isRecommended: Bool
    let languages: String

    var sizeLabel: String {
        sizeMB >= 1000 ? String(format: "%.1f GB", Double(sizeMB) / 1000) : "\(sizeMB) MB"
    }

    func name(_ lang: AppLanguage) -> String {
        lang == .ru ? russianName : englishName
    }

    func detail(_ lang: AppLanguage) -> String {
        lang == .ru ? russianDetail : englishDetail
    }
}

enum ModelCatalog {
    static let defaultID = "large-v3-v20240930_626MB"

    static let all: [ModelSpec] = [
        ModelSpec(
            id: "large-v3-v20240930_626MB",
            englishName: "Large v3 Turbo · Compact",
            russianName: "Large v3 Turbo · Компакт",
            englishDetail: "Best balance. Compressed turbo weights, runs on the Neural Engine.",
            russianDetail: "Лучший баланс. Сжатые turbo-веса, работа на Neural Engine.",
            sizeMB: 632,
            speed: 4,
            accuracy: 5,
            isRecommended: true,
            languages: "100+ languages"
        ),
        ModelSpec(
            id: "large-v3-v20240930_turbo",
            englishName: "Large v3 Turbo",
            russianName: "Large v3 Turbo",
            englishDetail: "Same model, uncompressed. A little more accurate, more disk and RAM.",
            russianDetail: "Та же модель без сжатия. Чуть точнее, больше диска и памяти.",
            sizeMB: 1620,
            speed: 3,
            accuracy: 5,
            isRecommended: false,
            languages: "100+ languages"
        ),
        ModelSpec(
            id: "small",
            englishName: "Small",
            russianName: "Small",
            englishDetail: "Light and quick. Good for clear speech and older Macs.",
            russianDetail: "Лёгкая и быстрая. Для чёткой речи и старых Mac.",
            sizeMB: 486,
            speed: 5,
            accuracy: 3,
            isRecommended: false,
            languages: "100+ languages"
        ),
        ModelSpec(
            id: "base",
            englishName: "Base",
            russianName: "Base",
            englishDetail: "Tiny footprint. Noticeably weaker on hard words and accents.",
            russianDetail: "Совсем маленькая. Заметно слабее на сложных словах и акцентах.",
            sizeMB: 148,
            speed: 5,
            accuracy: 2,
            isRecommended: false,
            languages: "100+ languages"
        )
    ]

    static func spec(id: String) -> ModelSpec? {
        all.first { $0.id == id }
    }

    static func modelFolder(for id: String) -> URL? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: AppPaths.models,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for case let url as URL in enumerator {
            guard url.lastPathComponent.contains(id) else { continue }
            let marker = url.appendingPathComponent("AudioEncoder.mlmodelc")
            if fm.fileExists(atPath: marker.path) {
                return url
            }
        }
        return nil
    }

    static func isInstalled(_ id: String) -> Bool {
        modelFolder(for: id) != nil
    }

    static func diskUsage() -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: AppPaths.models,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
        ) else { return 0 }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            if values?.isRegularFile == true {
                total += Int64(values?.fileSize ?? 0)
            }
        }
        return total
    }
}

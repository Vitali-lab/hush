import SwiftUI

struct ModelsView: View {
    @ObservedObject var model: AppModel

    private var t: Loc { Loc(model.settings.language) }

    private var currentSpec: ModelSpec? {
        ModelCatalog.spec(id: model.settings.modelID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(
                title: t("Model", "Модель"),
                subtitle: t(
                    "One download, then every word is transcribed on this Mac.",
                    "Одна загрузка — и каждое слово распознаётся на этом Mac."
                )
            )

            currentCard

            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(text: t("Available models", "Доступные модели"))

                ForEach(ModelCatalog.all) { spec in
                    ModelRow(
                        spec: spec,
                        lang: model.settings.language,
                        isSelected: model.settings.modelID == spec.id,
                        isInstalled: model.isInstalled(spec),
                        isDownloading: model.downloadingModelID == spec.id,
                        progress: progress(for: spec),
                        onSelect: { model.selectModel(spec) },
                        onDownload: { model.downloadModel(spec) }
                    )
                }
            }

            if case .failed(let message) = model.downloadState {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.amber)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t("Download failed", "Ошибка загрузки"))
                            .font(.system(size: 12, weight: .semibold))
                        Text(message)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardSurface(radius: 10)
            }

            HStack(spacing: 6) {
                Image(systemName: "internaldrive")
                Text(t(
                    "Models on disk: \(model.modelDiskUsage == 0 ? "none yet" : ByteCountFormatter.string(fromByteCount: model.modelDiskUsage, countStyle: .file))",
                    "Модели на диске: \(model.modelDiskUsage == 0 ? "пока нет" : ByteCountFormatter.string(fromByteCount: model.modelDiskUsage, countStyle: .file))"
                ))
                Spacer()
                Text("CoreML · Neural Engine")
            }
            .font(.system(size: 10.5))
            .foregroundStyle(.secondary)
        }
        .onAppear {
            model.refreshModelState()
        }
    }

    private func progress(for spec: ModelSpec) -> Double {
        guard model.downloadingModelID == spec.id else { return 0 }
        if case .downloading(let value) = model.downloadState { return value }
        return 0
    }

    private var currentCard: some View {
        Card {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Theme.brandGradient.opacity(0.16))
                        .frame(width: 42, height: 42)
                    Image(systemName: statusIcon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(statusColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(currentSpec?.name(model.settings.language) ?? t("No model", "Нет модели"))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text(statusDetail)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Badge(text: statusLabel, color: statusColor)
            }
        }
    }

    private var statusIcon: String {
        switch model.modelState {
        case .ready: return "checkmark"
        case .sleeping: return "moon.zzz"
        case .loading: return "waveform"
        case .notInstalled: return "arrow.down"
        case .failed: return "exclamationmark"
        }
    }

    private var statusLabel: String {
        switch model.modelState {
        case .ready: return t("Ready", "Готова")
        case .sleeping: return t("On disk", "На диске")
        case .loading: return t("Loading", "Загрузка")
        case .notInstalled: return t("Not installed", "Не установлена")
        case .failed: return t("Error", "Ошибка")
        }
    }

    private var statusColor: Color {
        switch model.modelState {
        case .ready, .sleeping: return Theme.green
        case .loading: return Theme.amber
        case .notInstalled: return .secondary
        case .failed: return Theme.danger
        }
    }

    private var statusDetail: String {
        switch model.modelState {
        case .ready:
            return t(
                "Loaded and warm. Hold the shortcut and speak.",
                "Загружена и готова. Зажми хоткей и говори."
            )
        case .sleeping:
            return t(
                "Saved on disk. It loads automatically on the first dictation.",
                "Лежит на диске. Загрузится сама при первой диктовке."
            )
        case .loading:
            return t(
                "Compiling for this Mac once — this can take a few seconds.",
                "Оптимизация под этот Mac — может занять пару секунд."
            )
        case .notInstalled:
            return t(
                "Download a model below to start dictating.",
                "Скачай модель ниже, чтобы начать диктовать."
            )
        case .failed(let message):
            return message
        }
    }
}

private struct ModelRow: View {
    let spec: ModelSpec
    let lang: AppLanguage
    let isSelected: Bool
    let isInstalled: Bool
    let isDownloading: Bool
    let progress: Double
    let onSelect: () -> Void
    let onDownload: () -> Void

    @Environment(\.colorScheme) private var scheme

    private var t: Loc { Loc(lang) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: isInstalled ? onSelect : onDownload) {
                    ZStack {
                        Circle()
                            .strokeBorder(
                                isSelected ? Theme.accent : Color.primary.opacity(0.2),
                                lineWidth: 1.5
                            )
                            .frame(width: 15, height: 15)
                        if isSelected {
                            Circle().fill(Theme.accent).frame(width: 7, height: 7)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text(spec.name(lang))
                            .font(.system(size: 13, weight: .semibold))
                        if spec.isRecommended {
                            Badge(text: t("Recommended", "Рекомендуем"), color: Theme.accent)
                        }
                    }

                    Text(spec.detail(lang))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 14) {
                        specItem(t("Size", "Размер"), spec.sizeLabel)
                        HStack(spacing: 5) {
                            Text(t("Speed", "Скорость"))
                            RatingDots(filled: spec.speed, total: 5, color: Theme.green)
                        }
                        HStack(spacing: 5) {
                            Text(t("Accuracy", "Точность"))
                            RatingDots(filled: spec.accuracy, total: 5, color: Theme.accent)
                        }
                    }
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .padding(.top, 1)
                }

                Spacer(minLength: 8)

                trailing
            }
            .padding(14)

            if isDownloading {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.primary.opacity(0.06))
                        Rectangle()
                            .fill(Theme.accentGradient)
                            .frame(width: max(0, proxy.size.width * progress))
                    }
                }
                .frame(height: 3)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(isSelected ? Theme.accent.opacity(0.07) : Theme.cardFill(scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(
                    isSelected ? Theme.accent.opacity(0.4) : Theme.cardStroke(scheme),
                    lineWidth: 1
                )
        )
        .animation(.easeOut(duration: 0.18), value: isSelected)
        .animation(.easeOut(duration: 0.2), value: isDownloading)
    }

    @ViewBuilder
    private var trailing: some View {
        if isDownloading {
            Text("\(Int(progress * 100))%")
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.accent)
        } else if isInstalled {
            if isSelected {
                Badge(text: t("In use", "Используется"), color: Theme.green)
            } else {
                Button(t("Use", "Выбрать"), action: onSelect)
                    .buttonStyle(SecondaryButtonStyle())
            }
        } else {
            Button(action: onDownload) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.down.circle")
                    Text(spec.sizeLabel)
                }
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private func specItem(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
            Text(value).foregroundStyle(.primary.opacity(0.8))
        }
    }
}

import AppKit
import Combine
import Foundation
import WhisperKit

enum DictationPhase: Equatable {
    case idle
    case listening
    case transcribing
    case done(String)
    case copied(String)
    case failed(String)

    var isActive: Bool {
        switch self {
        case .listening, .transcribing: return true
        default: return false
        }
    }
}

enum ModelLoadState: Equatable {
    case notInstalled
    case sleeping
    case loading
    case ready
    case failed(String)
}

enum DownloadState: Equatable {
    case idle
    case downloading(Double)
    case failed(String)
}

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    // MARK: - Published state

    @Published private(set) var phase: DictationPhase = .idle
    @Published private(set) var levels: [Float] = Array(repeating: 0, count: 42)
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var history: [HistoryEntry] = []
    @Published private(set) var modelState: ModelLoadState = .notInstalled
    @Published private(set) var downloadState: DownloadState = .idle
    @Published private(set) var modelDiskUsage: Int64 = 0
    @Published private(set) var downloadingModelID: String?
    @Published private(set) var isAccessibilityGranted = false
    @Published private(set) var isMicrophoneGranted = false
    @Published var lastResult: String = ""

    @Published var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            settingsStore.save(settings)
            applySettings(oldValue)
        }
    }

    // MARK: - Dependencies

    let recorder = AudioRecorder()
    let hotkeys = HotkeyManager()
    private let transcription = TranscriptionService()
    private let settingsStore = SettingsStore()
    private let historyStore = HistoryStore()

    var requestSettings: (() -> Void)?

    private var levelTimer: Timer?
    private var recordingStartedAt: Date?
    private var permissionTimer: Timer?
    private var loadedModelID: String?
    private var isStarting = false
    private var idleUnloadWork: DispatchWorkItem?

    private init() {
        settings = settingsStore.load()
        history = historyStore.load()
        ThemeRuntime.apply(settings.theme)
    }

    // MARK: - Lifecycle

    func start() {
        Log.info("Starting Hush; model installed: \(ModelCatalog.isInstalled(settings.modelID))")
        isAccessibilityGranted = Permissions.isAccessibilityGranted
        isMicrophoneGranted = Permissions.isMicrophoneGranted

        hotkeys.binding = settings.hotkey
        hotkeys.isListening = { [weak self] in self?.phase == .listening }
        hotkeys.onPress = { [weak self] in self?.beginDictation() }
        hotkeys.onRelease = { [weak self] in self?.finishDictation() }
        hotkeys.onToggle = { [weak self] in self?.toggleDictation() }
        hotkeys.onCancel = { [weak self] in self?.cancelDictation() }
        hotkeys.start()

        recorder.onLevel = { [weak self] level in
            DispatchQueue.main.async {
                self?.pushLevel(level)
            }
        }

        refreshModelState()
        refreshPermissions()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshPermissions() }
        }

        if ModelCatalog.isInstalled(settings.modelID) {
            Task { await prewarm() }
        }
    }

    func refreshPermissions() {
        isAccessibilityGranted = Permissions.isAccessibilityGranted
        isMicrophoneGranted = Permissions.isMicrophoneGranted
        if isAccessibilityGranted, isMicrophoneGranted, ModelCatalog.isInstalled(settings.modelID) {
            if !settings.hasCompletedSetup {
                settings.hasCompletedSetup = true
            }
        }
    }

    func requestMicrophone() {
        Task {
            let granted = await Permissions.Microphone.request()
            isMicrophoneGranted = granted
            if !granted {
                Permissions.openPrivacyPane("Privacy_Microphone")
            }
        }
    }

    func requestAccessibility() {
        Permissions.promptAccessibility()
        Permissions.openPrivacyPane("Privacy_Accessibility")
    }

    // MARK: - Dictation

    func toggleDictation() {
        switch phase {
        case .idle:
            beginDictation()
        case .listening:
            finishDictation()
        default:
            break
        }
    }

    func beginDictation() {
        guard phase == .idle, !isStarting else { return }

        guard ModelCatalog.isInstalled(settings.modelID) else {
            flashError(t("Download a model first", "Сначала скачай модель"))
            requestSettings?()
            return
        }

        guard Permissions.Microphone.isGranted else {
            Task {
                let granted = await Permissions.Microphone.request()
                isMicrophoneGranted = granted
                if !granted { flashError(t("Microphone access is off", "Нет доступа к микрофону")) }
            }
            return
        }

        isStarting = true
        defer { isStarting = false }
        idleUnloadWork?.cancel()

        do {
            try recorder.start()
        } catch {
            Log.error("Recorder failed: \(error.localizedDescription)")
            flashError(recorderMessage(error))
            return
        }

        recordingStartedAt = Date()
        elapsed = 0
        levels = Array(repeating: 0, count: 42)
        phase = .listening
        playFeedback(starting: true)
        startLevelTimer()

        Task {
            await ensureModelLoaded()
        }
    }

    func finishDictation() {
        guard phase == .listening else { return }
        stopLevelTimer()

        let samples = recorder.stop()
        let duration = recordingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName

        guard samples.count > 3_200 else {
            phase = .failed(t("Too short", "Слишком коротко"))
            scheduleIdle(after: 1.2)
            return
        }

        phase = .transcribing
        playFeedback(starting: false)

        Task {
            do {
                await ensureModelLoaded()
                let raw = try await transcription.transcribe(
                    samples: samples,
                    language: settings.language.whisperCode
                )
                let text = TextProcessor.process(raw, settings: settings)
                guard !text.isEmpty else {
                    phase = .failed(t("No speech detected", "Речь не распознана"))
                    scheduleIdle(after: 1.6)
                    return
                }

                let pasted = TextInserter.insert(text, autoPaste: settings.autoPaste)
                lastResult = text

                let entry = HistoryEntry(
                    text: text,
                    appName: appName,
                    duration: duration,
                    model: settings.modelID
                )
                addHistory(entry)

                phase = pasted ? .done(text) : .copied(text)
                scheduleIdle(after: pasted ? 1.6 : 2.6)
            } catch {
                Log.error("Transcription failed: \(error.localizedDescription)")
                phase = .failed(transcriptionMessage(error))
                scheduleIdle(after: 2.4)
            }
        }
    }

    func cancelDictation() {
        guard phase == .listening else { return }
        stopLevelTimer()
        recorder.cancel()
        phase = .idle
        elapsed = 0
    }

    private func ensureModelLoaded() async {
        let id = settings.modelID
        if loadedModelID == id, transcription.isLoaded { return }

        modelState = .loading
        do {
            try await transcription.loadModel(id)
            loadedModelID = id
            modelState = .ready
        } catch {
            Log.error("Model load failed: \(error.localizedDescription)")
            modelState = .failed(error.localizedDescription)
        }
    }

    private func prewarm() async {
        Log.info("Prewarming model \(settings.modelID)")
        modelState = .loading
        do {
            try await transcription.loadModel(settings.modelID)
            loadedModelID = settings.modelID
            modelState = .ready
            Log.info("Model prewarmed")
        } catch {
            modelState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Loading levels

    private func startLevelTimer() {
        stopLevelTimer()
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.phase == .listening else { return }
                self.elapsed = self.recordingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
                if self.elapsed >= self.settings.maxSeconds {
                    self.finishDictation()
                }
            }
        }
    }

    private func stopLevelTimer() {
        levelTimer?.invalidate()
        levelTimer = nil
    }

    private func pushLevel(_ level: Float) {
        guard phase == .listening else { return }
        var next = levels
        next.removeFirst()
        next.append(level)
        levels = next
    }

    private func scheduleIdle(after seconds: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            guard let self else { return }
            if self.phase.isActive { return }
            self.phase = .idle
            self.elapsed = 0
            self.scheduleIdleUnload()
        }
    }

    /// Keeps idle memory low: the model is unloaded after eight quiet minutes and
    /// reloaded on the next dictation (about a second on Apple Silicon).
    private func scheduleIdleUnload() {
        idleUnloadWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.phase == .idle, self.transcription.isLoaded else { return }
            self.transcription.unload()
            self.loadedModelID = nil
            if ModelCatalog.isInstalled(self.settings.modelID) {
                self.modelState = .sleeping
            }
        }
        idleUnloadWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 480, execute: work)
    }

    private func flashError(_ message: String) {
        phase = .failed(message)
        scheduleIdle(after: 2)
    }

    private func playFeedback(starting: Bool) {
        guard settings.playFeedbackSound else { return }
        NSSound(named: starting ? "Tink" : "Pop")?.play()
    }

    // MARK: - Models

    func refreshModelState() {
        modelDiskUsage = ModelCatalog.diskUsage()
        if loadedModelID == settings.modelID, transcription.isLoaded {
            modelState = .ready
        } else if ModelCatalog.isInstalled(settings.modelID) {
            if case .loading = modelState { return }
            modelState = .sleeping
        } else {
            modelState = .notInstalled
        }
    }

    func downloadModel(_ spec: ModelSpec) {
        guard case .downloading = downloadState else {
            downloadState = .downloading(0)
            downloadingModelID = spec.id
            Task {
                do {
                    _ = try await WhisperKit.download(
                        variant: spec.id,
                        downloadBase: AppPaths.models
                    ) { [weak self] progress in
                        let value = progress.fractionCompleted
                        Task { @MainActor in
                            guard let self else { return }
                            if case .downloading = self.downloadState {
                                self.downloadState = .downloading(value)
                            }
                        }
                    }

                    downloadState = .idle
                    downloadingModelID = nil
                    refreshModelState()
                    settings.modelID = spec.id
                    modelDiskUsage = ModelCatalog.diskUsage()
                    await ensureModelLoaded()
                } catch {
                    Log.error("Download failed: \(error.localizedDescription)")
                    downloadState = .failed(error.localizedDescription)
                    downloadingModelID = nil
                }
            }
            return
        }
    }

    func selectModel(_ spec: ModelSpec) {
        settings.modelID = spec.id
        loadedModelID = nil
        transcription.unload()
        refreshModelState()
        if ModelCatalog.isInstalled(spec.id) {
            Task { await ensureModelLoaded() }
        }
    }

    func isInstalled(_ spec: ModelSpec) -> Bool {
        ModelCatalog.isInstalled(spec.id)
    }

    // MARK: - History

    func addHistory(_ entry: HistoryEntry) {
        history.insert(entry, at: 0)
        if history.count > 500 {
            history = Array(history.prefix(500))
        }
        historyStore.save(history)
    }

    func deleteHistory(_ entry: HistoryEntry) {
        history.removeAll { $0.id == entry.id }
        historyStore.save(history)
    }

    func clearHistory() {
        history.removeAll()
        historyStore.save(history)
    }

    var totalWords: Int {
        history.reduce(0) { $0 + $1.text.split(separator: " ").count }
    }

    var todayWords: Int {
        let calendar = Calendar.current
        return history
            .filter { calendar.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.text.split(separator: " ").count }
    }

    var savedMinutes: Int {
        Int(Double(totalWords) / 40.0)
    }

    // MARK: - Settings plumbing

    private func applySettings(_ oldValue: AppSettings) {
        if settings.hotkey != oldValue.hotkey {
            hotkeys.binding = settings.hotkey
        }
        if settings.theme != oldValue.theme {
            ThemeRuntime.apply(settings.theme)
        }
        if settings.modelID != oldValue.modelID {
            loadedModelID = nil
            transcription.unload()
            refreshModelState()
        }
        if settings.launchAtLogin != oldValue.launchAtLogin {
            do {
                try LaunchAtLogin.set(settings.launchAtLogin)
            } catch {
                Log.error("Launch at login failed: \(error.localizedDescription)")
                settings.launchAtLogin = LaunchAtLogin.isEnabled
            }
        }
    }

    func setPhaseForPreview(_ newPhase: DictationPhase, levels: [Float]? = nil) {
        phase = newPhase
        if let levels {
            self.levels = levels
        }
    }

    func setModelStateForPreview(_ state: ModelLoadState) {
        modelState = state
    }

    private var t: Loc { Loc(settings.language) }

    private func recorderMessage(_ error: Error) -> String {
        if let recorderError = error as? AudioRecorder.RecorderError {
            switch recorderError {
            case .noInput:
                return t("No microphone found", "Микрофон не найден")
            case .engineFailed:
                return t("Could not start audio", "Не удалось запустить запись")
            case .converterFailed:
                return t("Audio format error", "Ошибка формата аудио")
            }
        }
        return t("Microphone error", "Ошибка микрофона")
    }

    private func transcriptionMessage(_ error: Error) -> String {
        if let serviceError = error as? TranscriptionService.ServiceError {
            switch serviceError {
            case .modelMissing:
                return t("The model is not downloaded", "Модель не скачана")
            case .emptyAudio:
                return t("Nothing was recorded", "Ничего не записали")
            case .noSpeech:
                return t("No speech detected", "Речь не распознана")
            }
        }
        return t("Transcription failed", "Ошибка распознавания")
    }
}

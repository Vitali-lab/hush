using System.ComponentModel;
using Hush.Core;

namespace Hush.Windows.Services;

/// <summary>
/// Tiny runtime localizer. XAML binds to the string indexer, so switching the
/// language refreshes every bound label at once.
/// </summary>
public sealed class Loc : INotifyPropertyChanged
{
    public static Loc Instance { get; } = new();

    private AppLanguage _language = AppLanguage.English;

    public event PropertyChangedEventHandler? PropertyChanged;

    public AppLanguage Language
    {
        get => _language;
        set
        {
            if (_language == value) return;
            _language = value;
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs("Item[]"));
        }
    }

    public string this[string key]
    {
        get
        {
            if (!Strings.TryGetValue(key, out var pair)) return key;
            return _language == AppLanguage.Russian ? pair.Ru : pair.En;
        }
    }

    private static readonly Dictionary<string, (string En, string Ru)> Strings = new()
    {
        ["AppName"] = ("Hush", "Hush"),
        ["Tagline"] = ("quiet dictation", "тихая диктовка"),
        ["NavGeneral"] = ("General", "Основное"),
        ["NavModel"] = ("Model", "Модель"),
        ["NavWords"] = ("Words", "Слова"),
        ["NavHistory"] = ("History", "История"),
        ["NavAbout"] = ("About", "О приложении"),

        ["StatusReady"] = ("Ready", "Готова"),
        ["StatusListening"] = ("Listening…", "Слушаю…"),
        ["StatusTranscribing"] = ("Transcribing…", "Распознаю…"),
        ["StatusPasted"] = ("Pasted", "Вставлено"),
        ["StatusCopied"] = ("Copied", "Скопировано"),
        ["StatusLoading"] = ("Loading model…", "Загружаю модель…"),
        ["StatusModelMissing"] = ("Model not installed", "Модель не установлена"),
        ["StatusModelOnDisk"] = ("Model on disk", "Модель на диске"),
        ["StatusModelReady"] = ("Model ready", "Модель готова"),
        ["StatusModelError"] = ("Model error", "Ошибка модели"),
        ["TrayTip"] = ("Hush — dictation", "Hush — диктовка"),
        ["TrayStart"] = ("Start dictation", "Начать диктовку"),
        ["TrayStop"] = ("Stop and paste", "Стоп и вставить"),
        ["TraySettings"] = ("Settings…", "Настройки…"),
        ["TrayQuit"] = ("Quit Hush", "Завершить Hush"),
        ["TrayOpen"] = ("Open Hush", "Открыть Hush"),

        ["GeneralTitle"] = ("General", "Основное"),
        ["GeneralSubtitle"] = ("Hold a key, speak, release. Your words land at the cursor.", "Зажми клавишу, говори, отпусти. Текст появится у курсора."),
        ["SetupTitle"] = ("Finish setup", "Заверши настройку"),
        ["SetupSubtitle"] = ("Two steps and you can dictate anywhere.", "Два шага — и можно диктовать где угодно."),
        ["SetupMic"] = ("Microphone", "Микрофон"),
        ["SetupMicOk"] = ("Windows is allowing microphone access", "Windows разрешает доступ к микрофону"),
        ["SetupMicNeeded"] = ("Allow microphone access in Windows Settings", "Разреши доступ к микрофону в настройках Windows"),
        ["SetupMicOpen"] = ("Open Settings", "Открыть настройки"),
        ["SetupModel"] = ("Speech model", "Речевая модель"),
        ["SetupModelOk"] = ("The model is downloaded", "Модель скачана"),
        ["SetupModelNeeded"] = ("Download a local model once", "Скачай локальную модель один раз"),
        ["SetupChoose"] = ("Choose", "Выбрать"),
        ["SetupNote"] = ("Hush works without an account and never uploads audio.", "Hush работает без аккаунта и не отправляет аудио."),
        ["MicHelp"] = ("Windows controls microphone access. If Hush cannot hear you, open Privacy & security → Microphone.", "Доступом к микрофону управляет Windows. Если Hush тебя не слышит, открой Privacy & security → Microphone."),

        ["ShortcutTitle"] = ("Shortcut", "Горячая клавиша"),
        ["ShortcutHint"] = ("Any key combination", "Любая комбинация клавиш"),
        ["ShortcutRecord"] = ("Record", "Записать"),
        ["ShortcutCancel"] = ("Cancel", "Отмена"),
        ["ShortcutCapturing"] = ("Press keys…", "Нажми клавиши…"),
        ["ShortcutHold"] = ("Hold", "Удерживать"),
        ["ShortcutToggle"] = ("Press to toggle", "Нажатие — старт/стоп"),
        ["ShortcutLetters"] = ("Modifiers and function keys can stand alone. Letters are safer with Ctrl, Alt or Shift.", "Модификаторы и F-клавиши могут работать сами по себе. Буквы надёжнее с Ctrl, Alt или Shift."),
        ["ShortcutWarning"] = ("A plain key will also fire while you type.", "Обычная клавиша будет срабатывать и во время набора."),
        ["ShortcutCaptureError"] = ("Press a key combination, a function key or a modifier.", "Нажми комбинацию, F-клавишу или модификатор."),
        ["ShortcutFnNote"] = ("Windows keyboards do not expose the Fn key to apps. Right Alt is the closest alternative.", "Windows-клавиатуры не отдают Fn приложениям. Правый Alt — ближайшая замена."),

        ["LanguageTitle"] = ("Language", "Язык"),
        ["LanguageHint"] = ("Switches the interface and the dictation language. Russian listens only in Russian, English only in English.", "Переключает интерфейс и язык распознавания. Русский — диктовка только по-русски, English — только по-английски."),

        ["SoundFeedback"] = ("Sound feedback", "Звуковой отклик"),
        ["SoundFeedbackDetail"] = ("A short cue when recording starts and stops.", "Короткий звук в начале и конце записи."),
        ["SoundStart"] = ("Start sound", "Звук старта"),
        ["SoundStopNote"] = ("The stop cue is a soft tick.", "На остановке звучит тихий щелчок."),

        ["ThemeTitle"] = ("Theme", "Тема"),
        ["ThemeHint"] = ("System follows Windows. The others lock light or dark and recolor accents.", "Системная следует за Windows. Остальные фиксируют светлую или тёмную и меняют акценты."),

        ["BehaviorTitle"] = ("Behavior", "Поведение"),
        ["AutoPaste"] = ("Paste automatically", "Вставлять автоматически"),
        ["AutoPasteDetail"] = ("Insert text at the cursor. Turn off to copy to clipboard only.", "Вставлять текст у курсора. Выключи, чтобы только копировать в буфер."),
        ["Fillers"] = ("Remove filler words", "Убирать слова-паразиты"),
        ["FillersDetail"] = ("Drops “um”, “uh”, “ээ”, “эм” and similar sounds.", "Убирает «ээ», «эм» и подобные звуки."),
        ["LaunchAtLogin"] = ("Launch at login", "Запускать при входе"),
        ["LaunchAtLoginDetail"] = ("Keep Hush ready in the tray after signing in.", "Hush будет ждать в трее после входа в Windows."),
        ["FooterPrivacy"] = ("Audio and text never leave this PC. No account, no cloud.", "Аудио и текст не покидают этот ПК. Без аккаунта и облака."),

        ["ModelTitle"] = ("Model", "Модель"),
        ["ModelSubtitle"] = ("One download, then every word is transcribed on this PC.", "Одна загрузка — и каждое слово распознаётся на этом ПК."),
        ["ModelsAvailable"] = ("Available models", "Доступные модели"),
        ["ModelRecommended"] = ("Recommended", "Рекомендуем"),
        ["ModelInUse"] = ("In use", "Используется"),
        ["ModelUse"] = ("Use", "Выбрать"),
        ["ModelDownload"] = ("Download", "Скачать"),
        ["ModelReady"] = ("Ready", "Готова"),
        ["ModelOnDisk"] = ("On disk", "На диске"),
        ["ModelLoading"] = ("Loading", "Загрузка"),
        ["ModelNotInstalled"] = ("Not installed", "Не установлена"),
        ["ModelError"] = ("Error", "Ошибка"),
        ["ModelReadyDetail"] = ("Loaded and warm. Press the shortcut and speak.", "Загружена и готова. Нажми хоткей и говори."),
        ["ModelOnDiskDetail"] = ("Saved on disk. It loads automatically on the first dictation.", "Лежит на диске. Загрузится сама при первой диктовке."),
        ["ModelLoadingDetail"] = ("Loading the model — this can take a few seconds.", "Загружаю модель — это может занять пару секунд."),
        ["ModelNotInstalledDetail"] = ("Download a model below to start dictating.", "Скачай модель ниже, чтобы начать диктовать."),
        ["ModelsOnDisk"] = ("Models on disk", "Модели на диске"),
        ["ModelSize"] = ("Size", "Размер"),
        ["ModelSpeed"] = ("Speed", "Скорость"),
        ["ModelAccuracy"] = ("Accuracy", "Точность"),
        ["ModelDownloadFailed"] = ("Download failed", "Ошибка загрузки"),
        ["ModelDownloadProgress"] = ("Downloading", "Скачиваю"),
        ["ModelDownloaded"] = ("Downloaded", "Скачана"),

        ["WordsTitle"] = ("Words", "Слова"),
        ["WordsSubtitle"] = ("Teach Hush names and jargon, and turn short phrases into snippets.", "Научи Hush именам и терминам, а короткие фразы превращай в готовые вставки."),
        ["CustomWords"] = ("Custom words", "Свои слова"),
        ["CustomWordsDetail"] = ("Say it one way, get it written your way. Case-insensitive, whole words.", "Говори как привык — получишь правильное написание. Без учёта регистра, целыми словами."),
        ["Add"] = ("Add", "Добавить"),
        ["NoWords"] = ("No custom words yet", "Пока нет своих слов"),
        ["WordsExample"] = ("Example: “кубернетес” → “Kubernetes”.", "Пример: «кубернетес» → «Kubernetes»."),
        ["HeardAs"] = ("Heard as…", "Слышится как…"),
        ["WriteAs"] = ("Write as…", "Писать как…"),
        ["Snippets"] = ("Snippets", "Сниппеты"),
        ["SnippetsDetail"] = ("Say the trigger on its own and Hush types the whole expansion.", "Скажи триггер отдельно — Hush вставит весь текст."),
        ["NoSnippets"] = ("No snippets yet", "Пока нет сниппетов"),
        ["SnippetsExample"] = ("Trigger: “my email”. Expansion: “hello@example.com”.", "Триггер: «мой имейл». Вставка: «hello@example.com»."),
        ["Trigger"] = ("Trigger phrase", "Фраза-триггер"),
        ["Expansion"] = ("Expansion", "Что вставить"),
        ["Delete"] = ("Delete", "Удалить"),

        ["HistoryTitle"] = ("History", "История"),
        ["HistorySubtitle"] = ("Everything you dictated, kept on this PC. Newest first.", "Всё, что ты надиктовал, хранится на этом ПК. Сначала новые."),
        ["WordsToday"] = ("words today", "слов сегодня"),
        ["WordsTotal"] = ("words total", "слов всего"),
        ["MinutesSaved"] = ("minutes saved", "минут сэкономлено"),
        ["SearchHistory"] = ("Search dictations", "Поиск по диктовкам"),
        ["NothingDictated"] = ("Nothing dictated yet", "Пока ничего не надиктовано"),
        ["NothingDictatedDetail"] = ("Press your shortcut and say something. The result shows up here.", "Зажми хоткей и скажи что-нибудь. Результат появится здесь."),
        ["NoMatches"] = ("No matches", "Ничего не найдено"),
        ["TryAnother"] = ("Try a different word.", "Попробуй другое слово."),
        ["Copy"] = ("Copy", "Копировать"),
        ["Copied"] = ("Copied", "Скопировано"),
        ["ClearHistory"] = ("Clear history", "Очистить историю"),
        ["ClearHistoryTitle"] = ("Clear history?", "Очистить историю?"),
        ["ClearHistoryMessage"] = ("This removes every saved dictation on this PC.", "Это удалит все сохранённые диктовки на этом ПК."),
        ["Cancel"] = ("Cancel", "Отмена"),
        ["Clear"] = ("Clear", "Очистить"),

        ["AboutTitle"] = ("About", "О приложении"),
        ["AboutSubtitle"] = ("A small, quiet dictation app. No account, no cloud, no telemetry.", "Маленькое тихое приложение для диктовки. Без аккаунта, облака и телеметрии."),
        ["AboutDescription"] = ("Hush turns speech into text on this PC. A global shortcut, a tiny floating pill, and your words at the cursor. Audio stays in memory and is never uploaded.", "Hush превращает речь в текст на этом ПК. Глобальный хоткей, маленькая плавающая пилюля и твои слова у курсора. Аудио остаётся в памяти и никуда не отправляется."),
        ["UnderTheHood"] = ("Under the hood", "Под капотом"),
        ["AboutWhisper"] = ("Whisper large-v3 Turbo", "Whisper large-v3 Turbo"),
        ["AboutWhisperDetail"] = ("whisper.cpp CPU build, running fully offline", "CPU-сборка whisper.cpp, полностью офлайн"),
        ["AboutRam"] = ("~300–600 MB RAM", "~300–600 МБ памяти"),
        ["AboutRamDetail"] = ("while transcribing, depending on the model", "во время распознавания, зависит от модели"),
        ["AboutOffline"] = ("Fully offline", "Полностью офлайн"),
        ["AboutOfflineDetail"] = ("after the one-time model download", "после одной загрузки модели"),
        ["AboutSpeed"] = ("Fast on a modern CPU", "Быстро на современном CPU"),
        ["AboutSpeedDetail"] = ("a minute of speech takes a few seconds", "минута речи — несколько секунд"),
        ["Shortcuts"] = ("Shortcuts", "Горячие клавиши"),
        ["ShortcutStartStop"] = ("Start / stop dictation", "Старт / стоп диктовки"),
        ["ShortcutCancelRecording"] = ("Cancel while recording", "Отмена во время записи"),
        ["ShortcutOpenSettings"] = ("Open settings", "Открыть настройки"),
        ["ShortcutQuit"] = ("Quit", "Выход"),
        ["Version"] = ("Version", "Версия"),
        ["License"] = ("MIT license", "лицензия MIT"),
        ["Credits"] = ("WhisperKit by Argmax · Whisper by OpenAI", "WhisperKit by Argmax · Whisper by OpenAI"),

        ["PhaseTooShort"] = ("Too short", "Слишком коротко"),
        ["PhaseNoSpeech"] = ("No speech detected", "Речь не распознана"),
        ["PhaseTranscriptionFailed"] = ("Transcription failed", "Ошибка распознавания"),
        ["PhaseModelMissing"] = ("Download a model first", "Сначала скачай модель"),
        ["PhaseMicDenied"] = ("Microphone access is off", "Нет доступа к микрофону"),
        ["PhaseMicError"] = ("Could not start the microphone", "Не удалось запустить микрофон"),
        ["PhaseRecordingError"] = ("Recording error", "Ошибка записи"),
        ["PhaseModelLoadFailed"] = ("Could not load the model", "Не удалось загрузить модель"),
        ["DownloadFailed"] = ("Download failed. Check the connection and retry.", "Ошибка загрузки. Проверь сеть и повтори."),
        ["ModelFileMissing"] = ("The model file is missing. Download it again from Settings.", "Файл модели отсутствует. Скачай её заново в настройках."),
        ["PasteFailed"] = ("Copied to clipboard", "Скопировано в буфер"),
        ["OpenMicSettings"] = ("Open microphone settings", "Открыть настройки микрофона"),
        ["HotkeyNotSet"] = ("Set a shortcut first", "Сначала назначь хоткей")
    };
}

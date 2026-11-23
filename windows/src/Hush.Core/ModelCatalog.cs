namespace Hush.Core;

public sealed record ModelSpec
{
    public required string Id { get; init; }
    public required string FileName { get; init; }
    public required string EnglishName { get; init; }
    public required string RussianName { get; init; }
    public required string EnglishDetail { get; init; }
    public required string RussianDetail { get; init; }
    public required int SizeMB { get; init; }
    public required int Speed { get; init; }
    public required int Accuracy { get; init; }
    public required string Url { get; init; }
    public bool IsRecommended { get; init; }

    public string Name(AppLanguage language) =>
        language == AppLanguage.Russian ? RussianName : EnglishName;

    public string Detail(AppLanguage language) =>
        language == AppLanguage.Russian ? RussianDetail : EnglishDetail;

    public string SizeLabel => SizeMB >= 1000
        ? $"{SizeMB / 1000.0:0.0} GB"
        : $"{SizeMB} MB";
}

public static class ModelCatalog
{
    private const string BaseUrl = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main";

    public const string DefaultId = "large-v3-turbo-q5";

    public static IReadOnlyList<ModelSpec> All { get; } =
    [
        new ModelSpec
        {
            Id = "large-v3-turbo-q5",
            FileName = "ggml-large-v3-turbo-q5_0.bin",
            EnglishName = "Large v3 Turbo · Compact",
            RussianName = "Large v3 Turbo · Компакт",
            EnglishDetail = "Best balance. Quantized turbo weights, fast on a modern CPU.",
            RussianDetail = "Лучший баланс. Квантованные turbo-веса, быстро на современном CPU.",
            SizeMB = 574,
            Speed = 4,
            Accuracy = 5,
            Url = $"{BaseUrl}/ggml-large-v3-turbo-q5_0.bin",
            IsRecommended = true
        },
        new ModelSpec
        {
            Id = "large-v3-turbo-q8",
            FileName = "ggml-large-v3-turbo-q8_0.bin",
            EnglishName = "Large v3 Turbo",
            RussianName = "Large v3 Turbo",
            EnglishDetail = "Same model with 8-bit weights. A little more accurate, more disk and RAM.",
            RussianDetail = "Та же модель с 8-битными весами. Чуть точнее, больше диска и памяти.",
            SizeMB = 1600,
            Speed = 3,
            Accuracy = 5,
            Url = $"{BaseUrl}/ggml-large-v3-turbo-q8_0.bin"
        },
        new ModelSpec
        {
            Id = "small",
            FileName = "ggml-small.bin",
            EnglishName = "Small",
            RussianName = "Small",
            EnglishDetail = "Light and quick. Good for clear speech and older PCs.",
            RussianDetail = "Лёгкая и быстрая. Для чёткой речи и старых ПК.",
            SizeMB = 466,
            Speed = 5,
            Accuracy = 3,
            Url = $"{BaseUrl}/ggml-small.bin"
        },
        new ModelSpec
        {
            Id = "base",
            FileName = "ggml-base.bin",
            EnglishName = "Base",
            RussianName = "Base",
            EnglishDetail = "Tiny footprint. Noticeably weaker on hard words and accents.",
            RussianDetail = "Совсем маленькая. Заметно слабее на сложных словах и акцентах.",
            SizeMB = 142,
            Speed = 5,
            Accuracy = 2,
            Url = $"{BaseUrl}/ggml-base.bin"
        }
    ];

    public static ModelSpec? Find(string id) => All.FirstOrDefault(m => m.Id == id);

    public static ModelSpec Default => Find(DefaultId) ?? All[0];
}

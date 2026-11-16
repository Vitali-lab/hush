import SwiftUI

struct DictionaryView: View {
    @ObservedObject var model: AppModel

    private var t: Loc { Loc(model.settings.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeader(
                title: t("Words", "Слова"),
                subtitle: t(
                    "Teach Hush names and jargon, and turn short phrases into full snippets.",
                    "Научи Hush именам и терминам, а короткие фразы превращай в готовые вставки."
                )
            )

            dictionaryCard
            snippetsCard
        }
    }

    // MARK: - Dictionary

    private var dictionaryCard: some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("Custom words", "Свои слова"))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text(t(
                        "Say it one way, get it written your way. Case-insensitive, whole words.",
                        "Говори как привык — получишь правильное написание. Без учёта регистра, целыми словами."
                    ))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        model.settings.dictionary.append(DictionaryEntry())
                    }
                } label: {
                    Label(t("Add", "Добавить"), systemImage: "plus")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            if model.settings.dictionary.isEmpty {
                EmptyState(
                    icon: "character.book.closed",
                    title: t("No custom words yet", "Пока нет своих слов"),
                    message: t(
                        "Example: “кубернетес” → “Kubernetes”, or “доктор смит” → “Dr. Smith”.",
                        "Пример: «кубернетес» → «Kubernetes» или «доктор смит» → «Dr. Smith»."
                    )
                )
            } else {
                VStack(spacing: 8) {
                    ForEach($model.settings.dictionary) { $entry in
                        HStack(spacing: 8) {
                            TextField(t("Heard as…", "Слышится как…"), text: $entry.spoken)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(fieldBackground)

                            Image(systemName: "arrow.right")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)

                            TextField(t("Write as…", "Писать как…"), text: $entry.written)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(fieldBackground)

                            Button {
                                remove(entry.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(IconButtonStyle(tint: Theme.danger.opacity(0.8)))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Snippets

    private var snippetsCard: some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("Snippets", "Сниппеты"))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text(t(
                        "Say the trigger on its own and Hush types the whole expansion.",
                        "Скажи триггер отдельно — Hush вставит весь текст."
                    ))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        model.settings.snippets.append(Snippet())
                    }
                } label: {
                    Label(t("Add", "Добавить"), systemImage: "plus")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            if model.settings.snippets.isEmpty {
                EmptyState(
                    icon: "text.append",
                    title: t("No snippets yet", "Пока нет сниппетов"),
                    message: t(
                        "Trigger: “my email”. Expansion: “hello@example.com”.",
                        "Триггер: «мой имейл». Вставка: «hello@example.com»."
                    )
                )
            } else {
                VStack(spacing: 8) {
                    ForEach($model.settings.snippets) { $snippet in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                TextField(t("Trigger phrase", "Фраза-триггер"), text: $snippet.trigger)
                                    .textFieldStyle(.plain)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                                    .background(fieldBackground)

                                Button {
                                    removeSnippet(snippet.id)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(IconButtonStyle(tint: Theme.danger.opacity(0.8)))
                            }

                            TextField(t("Expansion", "Что вставить"), text: $snippet.expansion, axis: .vertical)
                                .textFieldStyle(.plain)
                                .lineLimit(1...4)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(fieldBackground)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.primary.opacity(0.025))
                        )
                    }
                }
            }
        }
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(Color.primary.opacity(0.05))
    }

    private func remove(_ id: UUID) {
        withAnimation(.snappy(duration: 0.2)) {
            model.settings.dictionary.removeAll { $0.id == id }
        }
    }

    private func removeSnippet(_ id: UUID) {
        withAnimation(.snappy(duration: 0.2)) {
            model.settings.snippets.removeAll { $0.id == id }
        }
    }
}

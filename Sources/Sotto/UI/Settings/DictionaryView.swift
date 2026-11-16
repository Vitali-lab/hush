import SwiftUI

struct DictionaryView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeader(
                title: "Words",
                subtitle: "Teach Sotto names and jargon, and turn short phrases into full snippets."
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
                    Text("Custom words")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text("Say it one way, get it written your way. Case-insensitive, whole words.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        model.settings.dictionary.append(DictionaryEntry())
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            if model.settings.dictionary.isEmpty {
                EmptyState(
                    icon: "character.book.closed",
                    title: "No custom words yet",
                    message: "Example: “кубернетес” → “Kubernetes”, or “доктор смит” → “Dr. Smith”."
                )
            } else {
                VStack(spacing: 8) {
                    ForEach($model.settings.dictionary) { $entry in
                        HStack(spacing: 8) {
                            TextField("Heard as…", text: $entry.spoken)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(fieldBackground)

                            Image(systemName: "arrow.right")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)

                            TextField("Write as…", text: $entry.written)
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
                    Text("Snippets")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text("Say the trigger on its own and Sotto types the whole expansion.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        model.settings.snippets.append(Snippet())
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            if model.settings.snippets.isEmpty {
                EmptyState(
                    icon: "text.append",
                    title: "No snippets yet",
                    message: "Trigger: “my email”. Expansion: “hello@example.com”."
                )
            } else {
                VStack(spacing: 8) {
                    ForEach($model.settings.snippets) { $snippet in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                TextField("Trigger phrase", text: $snippet.trigger)
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

                            TextField("Expansion", text: $snippet.expansion, axis: .vertical)
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

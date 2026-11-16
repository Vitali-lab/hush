import SwiftUI

struct HistoryView: View {
    @ObservedObject var model: AppModel
    @State private var query = ""
    @State private var copiedID: UUID?

    private var filtered: [HistoryEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return model.history }
        return model.history.filter { $0.text.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(
                title: "History",
                subtitle: "Everything you dictated, kept on this Mac. Newest first."
            )

            statsRow

            searchField

            if filtered.isEmpty {
                Card {
                    EmptyState(
                        icon: "mic.badge.plus",
                        title: query.isEmpty ? "Nothing dictated yet" : "No matches",
                        message: query.isEmpty
                            ? "Hold your shortcut and say something. The result shows up here."
                            : "Try a different word."
                    )
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(filtered) { entry in
                        HistoryRow(
                            entry: entry,
                            isCopied: copiedID == entry.id,
                            onCopy: {
                                TextInserter.copy(entry.text)
                                copiedID = entry.id
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    if copiedID == entry.id { copiedID = nil }
                                }
                            },
                            onDelete: {
                                model.deleteHistory(entry)
                            }
                        )
                    }
                }

                if !model.history.isEmpty {
                    Button {
                        model.clearHistory()
                    } label: {
                        Text("Clear history")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Theme.danger.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 2)
                }
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatTile(value: "\(model.todayWords)", label: "words today", color: Theme.accent)
            StatTile(value: "\(model.totalWords)", label: "words total", color: Theme.green)
            StatTile(value: "\(model.savedMinutes)", label: "minutes saved", color: Theme.pink)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Search dictations", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }
}

private struct StatTile: View {
    let value: String
    let label: String
    let color: Color
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Theme.cardFill(scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Theme.cardStroke(scheme), lineWidth: 1)
        )
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry
    let isCopied: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(entry.text)
                .font(.system(size: 12.5))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Text(entry.date, format: .dateTime.day().month().hour().minute())
                    .font(.system(size: 10.5))
                if let app = entry.appName {
                    Text("·")
                    Text(app)
                        .font(.system(size: 10.5))
                }
                if entry.duration > 0.5 {
                    Text("·")
                    Text(String(format: "%.0fs", entry.duration))
                        .font(.system(size: 10.5))
                }
                Spacer()

                if hovering {
                    Button(action: onCopy) {
                        Label(isCopied ? "Copied" : "Copy", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(isCopied ? Theme.green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(hovering ? Color.primary.opacity(0.05) : Theme.cardFill(scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Theme.cardStroke(scheme), lineWidth: 1)
        )
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .contextMenu {
            Button("Copy", action: onCopy)
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}

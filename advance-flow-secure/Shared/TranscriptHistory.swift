import Foundation

/// One saved dictation.
struct TranscriptEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let date: Date
}

/// Keeps the last dictations so you can grab a sentence back from ten minutes
/// ago. Stored only on-device (a JSON file in Application Support) — nothing
/// syncs anywhere, and Clear wipes the file for good.
@MainActor
final class TranscriptHistory: ObservableObject {
    @Published private(set) var entries: [TranscriptEntry] = []

    private let maxEntries = 50

    private let fileURL: URL = {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AdvanceFlowSecure", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("history.json")
    }()

    init() {
        load()
    }

    func add(_ text: String) {
        entries.insert(TranscriptEntry(id: UUID(), text: text, date: Date()), at: 0)
        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }
        save()
    }

    func clear() {
        entries = []
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        entries = (try? JSONDecoder().decode([TranscriptEntry].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

import Foundation

struct LocalDialogMessage: Codable, Equatable {
    let role: String
    let text: String
    let timestamp: Int
}

struct LocalDialogRecord: Codable, Equatable {
    let dialogId: String
    var messages: [LocalDialogMessage]
}

final class LocalDialogStore {
    static let userRole = "user"
    static let assistantRole = "assistant"

    private let dialogId: String
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(dialogId: String, fileManager: FileManager = .default) {
        self.dialogId = dialogId

        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let directory = baseDirectory.appendingPathComponent("LingoBuddy/Dialogs", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let safeFileName = dialogId
            .map { character -> Character in
                character.isLetter || character.isNumber || character == "-" || character == "_" ? character : "_"
            }
        self.fileURL = directory.appendingPathComponent(String(safeFileName)).appendingPathExtension("json")

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func append(role: String, text: String, timestamp: Int = Int(Date().timeIntervalSince1970)) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        var record = loadRecord()
        record.messages.append(LocalDialogMessage(role: role, text: trimmedText, timestamp: timestamp))
        save(record)
    }

    func allMessages() -> [LocalDialogMessage] {
        loadRecord().messages
    }

    func recentContext(maxQAPairs: Int) -> [[String: Any]] {
        let maxMessages = max(0, maxQAPairs * 2)
        guard maxMessages > 0 else { return [] }

        return allMessages()
            .suffix(maxMessages)
            .map { message in
                [
                    "role": message.role,
                    "text": message.text,
                    "timestamp": message.timestamp
                ]
            }
    }

    private func loadRecord() -> LocalDialogRecord {
        guard let data = try? Data(contentsOf: fileURL) else {
            return LocalDialogRecord(dialogId: dialogId, messages: [])
        }

        guard let record = try? decoder.decode(LocalDialogRecord.self, from: data), record.dialogId == dialogId else {
            return LocalDialogRecord(dialogId: dialogId, messages: [])
        }

        return record
    }

    private func save(_ record: LocalDialogRecord) {
        guard let data = try? encoder.encode(record) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}

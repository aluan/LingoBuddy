import Foundation
import UniformTypeIdentifiers

struct SharedImportItem: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case text
        case url
        case image
        case pdf
        case file
    }

    let id: String
    let kind: Kind
    let text: String?
    let fileName: String?
    let mimeType: String?
    let relativeFilePath: String?
    let createdAt: Date
}

@MainActor
final class SharedImportStore: ObservableObject {
    static let appGroupIdentifier = "group.com.aluan.LingoBuddys"
    static let pendingItemsKey = "pendingSharedImportItems"
    static let importURLScheme = "lingobuddy"

    @Published private(set) var pendingItems: [SharedImportItem] = []

    init() {
        reload()
    }

    func reload() {
        pendingItems = Self.loadPendingItems()
    }

    func remove(_ item: SharedImportItem) {
        var items = Self.loadPendingItems()
        items.removeAll { $0.id == item.id }
        Self.savePendingItems(items)
        pendingItems = items
    }

    func fileURL(for item: SharedImportItem) -> URL? {
        guard let relativeFilePath = item.relativeFilePath,
              let containerURL = Self.containerURL() else { return nil }
        return containerURL.appendingPathComponent(relativeFilePath)
    }

    static func loadPendingItems() -> [SharedImportItem] {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: pendingItemsKey),
              let items = try? JSONDecoder().decode([SharedImportItem].self, from: data) else {
            return []
        }
        return items.sorted { $0.createdAt < $1.createdAt }
    }

    static func append(_ item: SharedImportItem) {
        var items = loadPendingItems()
        items.append(item)
        savePendingItems(items)
    }

    static func savePendingItems(_ items: [SharedImportItem]) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: pendingItemsKey)
    }

    static func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    static func sharedFilesDirectory() throws -> URL {
        guard let containerURL = containerURL() else {
            throw CocoaError(.fileNoSuchFile)
        }
        let directory = containerURL.appendingPathComponent("SharedImports", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

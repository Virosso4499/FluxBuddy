import Foundation

enum Storage {
    private static let fileName = "transactions.json"

    private static var url: URL {
        let docs = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        return docs.appendingPathComponent(fileName)
    }

    static func load() -> [Transaction] {
        guard let data = try? Data(contentsOf: url) else {
            return []
        }
        return (try? JSONDecoder().decode([Transaction].self, from: data)) ?? []
    }

    static func save(_ items: [Transaction]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: url, options: [.atomic])
    }
}

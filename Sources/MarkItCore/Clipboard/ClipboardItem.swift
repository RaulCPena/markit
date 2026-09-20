import Foundation

public struct ClipboardItem: Codable, Equatable, Identifiable {
    public let id: UUID
    public let text: String
    public let timestamp: Date
    public var isPinned: Bool

    public init(id: UUID = UUID(), text: String, timestamp: Date = Date(), isPinned: Bool = false) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.isPinned = isPinned
    }

    enum CodingKeys: String, CodingKey {
        case id, text, timestamp, isPinned
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }
}

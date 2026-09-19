import Foundation

public struct ClipboardItem: Codable, Equatable, Identifiable {
    public let id: UUID
    public let text: String
    public let timestamp: Date
}

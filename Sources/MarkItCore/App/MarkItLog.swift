import Foundation
import os.log

enum MarkItLog {
    static let fileURL: URL = {
        let logs = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        return logs.appendingPathComponent("MarkIt.log")
    }()

    static func line(_ message: String) {
        os_log("%{public}@", message)
        let stamped = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        guard let data = stamped.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: fileURL.path) {
            guard let handle = try? FileHandle(forWritingTo: fileURL) else { return }
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: fileURL)
        }
    }
}

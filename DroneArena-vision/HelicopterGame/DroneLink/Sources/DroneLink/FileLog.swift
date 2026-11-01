import Foundation

/// Append-only session log on disk: Documents/DroneLogs/<yyyyMMdd-HHmmss>.log.
/// Every packet, state change and failure lands here so it survives a crash and can be
/// pulled from the device with scripts/pull-drone-logs.sh (devicectl app container copy).
public final class FileLog: @unchecked Sendable {
    public static let shared: FileLog = {
        let n = ProcessInfo.processInfo.processName
        let testing = n.contains("xctest") || n.contains("swiftpm-testing") || n.hasSuffix("PackageTests")
        return testing ? FileLog(directory: nil) : FileLog()
    }()

    public let url: URL?
    private let q = DispatchQueue(label: "dronelink.filelog")
    private var handle: FileHandle?
    private let stamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    public init(directory: URL? = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first) {
        guard let base = directory?.appendingPathComponent("DroneLogs", isDirectory: true) else { url = nil; return }
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let name = DateFormatter()
        name.dateFormat = "yyyyMMdd-HHmmss"
        let u = base.appendingPathComponent("\(name.string(from: Date())).log")
        FileManager.default.createFile(atPath: u.path, contents: nil)
        url = u
        handle = try? FileHandle(forWritingTo: u)
        Self.prune(base, keep: 30)
    }

    /// "HH:mm:ss.SSS <tag> <text>"
    public func write(_ tag: String, _ text: String) {
        let line = "\(stamp.string(from: Date())) \(tag) \(text)\n"
        q.async { [weak self] in
            guard let h = self?.handle else { return }
            h.seekToEndOfFile()
            h.write(Data(line.utf8))
        }
    }

    /// Blocks until queued lines are on disk (tests, app background).
    public func sync() { q.sync { try? handle?.synchronize() } }

    private static func prune(_ dir: URL, keep: Int) {
        let files = ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "log" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
        for f in files.dropFirst(keep) { try? FileManager.default.removeItem(at: f) }
    }
}

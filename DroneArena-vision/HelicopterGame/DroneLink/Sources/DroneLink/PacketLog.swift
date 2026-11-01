import Foundation
import Observation

/// Ring buffer of the last `capacity` command packets, for the debug view.
@MainActor @Observable
public final class PacketLog {
    public enum Direction: String, Sendable { case tx, rx }

    public struct Entry: Identifiable, Sendable {
        public let id: Int
        public let time: Date
        public let direction: Direction
        public let text: String
    }

    public let capacity: Int
    public private(set) var entries: [Entry] = []
    @ObservationIgnored private var nextID = 0

    public init(capacity: Int = 200) { self.capacity = max(1, capacity) }

    public func append(_ direction: Direction, _ text: String, at time: Date = Date()) {
        entries.append(Entry(id: nextID, time: time, direction: direction, text: text))
        nextID += 1
        if entries.count > capacity { entries.removeFirst(entries.count - capacity) }
    }

    public func clear() { entries.removeAll() }

    /// One line per entry: "HH:mm:ss.SSS tx command".
    public var text: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return entries.map { "\(f.string(from: $0.time)) \($0.direction.rawValue) \($0.text)" }.joined(separator: "\n")
    }
}

import Foundation

/// One NAL unit without its start code.
public struct NALUnit: Equatable, Sendable {
    public let bytes: [UInt8]
    public init(bytes: [UInt8]) { self.bytes = bytes }
    /// nal_unit_type, low 5 bits of the header byte. 1 slice, 5 IDR, 7 SPS, 8 PPS.
    public var type: UInt8 { bytes.first.map { $0 & 0x1F } ?? 0 }
}

/// Incremental Annex B splitter. Feed datagram-sized chunks; a NAL is emitted once
/// the next start code (3 or 4 bytes) arrives, or on `flush()`.
public struct H264NALParser: Sendable {
    private var buffer: [UInt8] = []

    public init() {}

    public mutating func feed(_ data: [UInt8]) -> [NALUnit] {
        buffer.append(contentsOf: data)
        var starts: [(pos: Int, len: Int)] = []
        var i = 0
        let n = buffer.count
        while i + 3 <= n {
            if buffer[i] == 0, buffer[i + 1] == 0 {
                if buffer[i + 2] == 1 { starts.append((i, 3)); i += 3; continue }
                if i + 4 <= n, buffer[i + 2] == 0, buffer[i + 3] == 1 { starts.append((i, 4)); i += 4; continue }
            }
            i += 1
        }
        guard !starts.isEmpty else {
            // No start code yet. Keep a small tail so a start code split across chunks survives.
            if buffer.count > 4_000_000 { buffer.removeAll() }
            return []
        }
        var out: [NALUnit] = []
        for k in 0..<(starts.count - 1) {
            let begin = starts[k].pos + starts[k].len
            let end = starts[k + 1].pos
            if end > begin { out.append(NALUnit(bytes: Array(buffer[begin..<end]))) }
        }
        // A trailing 4-byte start code may be a partial "00 00 00 01" prefix; keep from the last start.
        buffer.removeSubrange(0..<starts[starts.count - 1].pos)
        return out
    }

    /// Emits the pending NAL, if any, and clears state.
    public mutating func flush() -> [NALUnit] {
        defer { buffer.removeAll() }
        var i = 0
        if buffer.count >= 4, buffer[0] == 0, buffer[1] == 0, buffer[2] == 0, buffer[3] == 1 { i = 4 }
        else if buffer.count >= 3, buffer[0] == 0, buffer[1] == 0, buffer[2] == 1 { i = 3 }
        else { return [] }
        return buffer.count > i ? [NALUnit(bytes: Array(buffer[i...]))] : []
    }
}

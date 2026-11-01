import CoreGraphics
import Foundation

/// Associates per-frame detections into tracks and rates collision threat.
public struct ObstacleTracker: Sendable {
    /// Flight corridor in normalized image coordinates (drone width plus margin ahead).
    public var corridor = CGRect(x: 0.32, y: 0.2, width: 0.36, height: 0.65)
    public var brakeTTC = 1.5
    public var warnTTC = 3.0
    public var brakeRangeM = 1.0
    public var warnRangeM = 2.5
    public var maxMisses = 3
    public var minHits = 2

    private struct Track: Sendable {
        var id: Int
        var kind: ObstacleKind
        var rect: CGRect
        var range: Double?
        var ttc: Double?
        var hits = 1
        var misses = 0
        var lastAt: TimeInterval
    }

    private var tracks: [Track] = []
    private var nextID = 1

    public init() {}

    public mutating func reset() { tracks.removeAll() }

    /// `speedCMS` is forward ground speed (cm/s), 0 when unknown or hovering.
    public mutating func update(_ dets: [ObstacleDetection], at t: TimeInterval, speedCMS: Double) -> [Obstacle] {
        var used = Set<Int>()
        for i in tracks.indices {
            var best = -1
            var bestScore = 0.0
            for (j, d) in dets.enumerated() where !used.contains(j) {
                let s = Self.match(tracks[i].rect, d.rect)
                if s > bestScore { bestScore = s; best = j }
            }
            if best >= 0, bestScore > 0.15 {
                used.insert(best)
                Self.step(&tracks[i], dets[best], at: t, speedCMS: speedCMS)
            } else {
                tracks[i].misses += 1
            }
        }
        tracks.removeAll { $0.misses > maxMisses || t - $0.lastAt > 0.8 }
        for (j, d) in dets.enumerated() where !used.contains(j) {
            tracks.append(Track(id: nextID, kind: d.kind, rect: d.rect, range: Self.range(d), lastAt: t))
            nextID += 1
        }
        return tracks.filter { $0.hits >= minHits }.map(obstacle).sorted { $0.threat > $1.threat }
    }

    private static func step(_ tr: inout Track, _ d: ObstacleDetection, at t: TimeInterval, speedCMS: Double) {
        let dt = max(t - tr.lastAt, 1e-3)
        let s0 = sqrt(Double(tr.rect.width * tr.rect.height))
        let s1 = sqrt(Double(d.rect.width * d.rect.height))
        let rate = (s1 / max(s0, 1e-4) - 1) / dt
        let expTTC: Double? = rate > 0.03 ? 1 / rate : nil
        let r = Self.range(d)
        let rangeTTC: Double? = (speedCMS > 20 && r != nil) ? r! / (speedCMS / 100) : nil
        let raw = [expTTC, rangeTTC].compactMap { $0 }.min()
        if let raw { tr.ttc = tr.ttc.map { $0 * 0.5 + raw * 0.5 } ?? raw } else { tr.ttc = nil }
        if let r { tr.range = tr.range.map { $0 * 0.6 + r * 0.4 } ?? r }
        else if let ttc = tr.ttc, speedCMS > 20 { tr.range = ttc * speedCMS / 100 }
        tr.rect = d.rect
        tr.kind = d.kind
        tr.hits += 1
        tr.misses = 0
        tr.lastAt = t
    }

    private func obstacle(_ tr: Track) -> Obstacle {
        let inPath = tr.rect.intersects(corridor)
        var threat: ThreatLevel = inPath ? .watch : .clear
        let ttc = tr.ttc ?? .infinity
        let rng = tr.range ?? .infinity
        if inPath, ttc < brakeTTC || rng < brakeRangeM { threat = .brake }
        else if inPath, ttc < warnTTC || rng < warnRangeM { threat = .warn }
        return Obstacle(id: tr.id, kind: tr.kind, rect: tr.rect, distanceM: tr.range, ttc: tr.ttc,
                        bearing: TelloCamera.bearing(x: Double(tr.rect.midX)),
                        elevation: TelloCamera.elevation(y: Double(tr.rect.midY)),
                        inPath: inPath, threat: threat)
    }

    static func range(_ d: ObstacleDetection) -> Double? {
        d.kind.widthM.map { TelloCamera.range(widthNorm: Double(d.rect.width), realM: $0) }
    }

    /// IoU, or a center-distance score for small fast-moving boxes.
    static func match(_ a: CGRect, _ b: CGRect) -> Double {
        let i = a.intersection(b)
        let inter = i.isNull ? 0 : Double(i.width * i.height)
        let uni = Double(a.width * a.height + b.width * b.height) - inter
        let iou = uni > 0 ? inter / uni : 0
        let dc = hypot(Double(a.midX - b.midX), Double(a.midY - b.midY))
        return max(iou, dc < 0.08 ? 0.2 : 0)
    }
}

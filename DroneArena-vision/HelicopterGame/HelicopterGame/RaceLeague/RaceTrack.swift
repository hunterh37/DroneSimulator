//
//  RaceTrack.swift
//  HelicopterGame
//
//  Parametric closed-loop race tracks, arc-length sampled for CPU racing lines and
//  gate placement. Coordinates are local to the arena root, meters, y up.
//

import Foundation
import simd

enum RaceTrackID: String, CaseIterable, Identifiable, Codable {
    case neonOval, stadiumEight, skylineClover

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .neonOval: return "Neon Oval"
        case .stadiumEight: return "Stadium Eight"
        case .skylineClover: return "Skyline Clover"
        }
    }

    var subtitle: String {
        switch self {
        case .neonOval: return "Flat-out speedway, gentle elevation"
        case .stadiumEight: return "Figure eight with an overpass crossover"
        case .skylineClover: return "Three-lobe climb with dive gates"
        }
    }

    var gateCount: Int {
        switch self {
        case .neonOval: return 8
        case .stadiumEight: return 10
        case .skylineClover: return 12
        }
    }

    /// Curve position for t in [0, 2pi). t = 0 is the start/finish gate.
    func point(_ t: Float) -> SIMD3<Float> {
        switch self {
        case .neonOval:
            return [9.5 * sin(t), 1.5 + 0.45 * sin(2 * t), -5.5 + 5.5 * cos(t)]
        case .stadiumEight:
            let u = t + .pi / 2
            return [7.5 * sin(2 * u), 1.95 + 0.95 * cos(u), -12 * sin(u)]
        case .skylineClover:
            let r = 8.5 + 3.0 * cos(3 * t)
            return [r * sin(t), 2.5 + 1.15 * cos(3 * t) + 0.35 * sin(t), -r * cos(t) + 11.5]
        }
    }
}

struct RaceGate {
    let index: Int
    let position: SIMD3<Float>
    let forward: SIMD3<Float>
    let s: Float
    let halfSize: Float
}

/// Arc-length parameterised sampling of a RaceTrackID.
struct RaceTrack {
    let id: RaceTrackID
    let samples: [SIMD3<Float>]
    let cumulative: [Float]
    let length: Float
    let gates: [RaceGate]
    let curvature: [Float]

    private static let sampleCount = 720

    init(_ id: RaceTrackID) {
        self.id = id
        var pts: [SIMD3<Float>] = []
        pts.reserveCapacity(Self.sampleCount + 1)
        for i in 0...Self.sampleCount {
            pts.append(id.point(Float(i) / Float(Self.sampleCount) * 2 * .pi))
        }
        var cum: [Float] = [0]
        for i in 1..<pts.count { cum.append(cum[i - 1] + simd_distance(pts[i], pts[i - 1])) }
        samples = pts
        cumulative = cum
        length = cum.last ?? 1

        var k: [Float] = []
        let n = pts.count - 1
        for i in 0..<pts.count {
            let a = pts[(i - 4 + n) % n], b = pts[i % n], c = pts[(i + 4) % n]
            let t1 = normalize(b - a), t2 = normalize(c - b)
            let ds = max(0.001, simd_distance(a, c) * 0.5)
            let turn = acos(max(-1, min(1, dot(SIMD2(t1.x, t1.z) / max(0.001, simd_length(SIMD2(t1.x, t1.z))), SIMD2(t2.x, t2.z) / max(0.001, simd_length(SIMD2(t2.x, t2.z)))))))
            let side: Float = (t1.x * t2.z - t1.z * t2.x) >= 0 ? 1 : -1
            k.append(side * turn / ds)
        }
        curvature = k

        var g: [RaceGate] = []
        let total = cum.last ?? 1
        for i in 0..<id.gateCount {
            let s = total * Float(i) / Float(id.gateCount)
            let p = Self.sample(pts, cum, total, s)
            let f = Self.tangent(pts, cum, total, s)
            g.append(RaceGate(index: i, position: p, forward: f, s: s, halfSize: 0.75))
        }
        gates = g
    }

    func position(at s: Float) -> SIMD3<Float> { Self.sample(samples, cumulative, length, s) }
    func tangent(at s: Float) -> SIMD3<Float> { Self.tangent(samples, cumulative, length, s) }

    func curvature(at s: Float) -> Float {
        let w = wrap(s)
        let i = index(for: w)
        return curvature[min(i, curvature.count - 1)]
    }

    /// Max |curvature| over the next `ahead` meters (for CPU braking).
    func peakCurvature(from s: Float, ahead: Float) -> Float {
        var peak: Float = 0
        var d: Float = 0
        while d <= ahead {
            peak = max(peak, abs(curvature(at: s + d)))
            d += 0.5
        }
        return peak
    }

    func wrap(_ s: Float) -> Float {
        let m = s.truncatingRemainder(dividingBy: length)
        return m < 0 ? m + length : m
    }

    /// Gates passed for an unbounded distance s (s = 0 is crossing gate 0 for the first time).
    func gatesPassed(at s: Float) -> Int {
        guard s >= 0 else { return 0 }
        let lap = Int(s / length)
        let frac = s - Float(lap) * length
        let inLap = gates.filter { $0.s <= frac }.count
        return lap * gates.count + inLap
    }

    private func index(for w: Float) -> Int {
        var lo = 0, hi = cumulative.count - 1
        while lo < hi {
            let mid = (lo + hi) / 2
            if cumulative[mid] < w { lo = mid + 1 } else { hi = mid }
        }
        return max(1, lo)
    }

    private static func sample(_ pts: [SIMD3<Float>], _ cum: [Float], _ total: Float, _ s: Float) -> SIMD3<Float> {
        var w = s.truncatingRemainder(dividingBy: total)
        if w < 0 { w += total }
        var lo = 0, hi = cum.count - 1
        while lo < hi {
            let mid = (lo + hi) / 2
            if cum[mid] < w { lo = mid + 1 } else { hi = mid }
        }
        let i = max(1, lo)
        let span = max(0.0001, cum[i] - cum[i - 1])
        return simd_mix(pts[i - 1], pts[i], SIMD3(repeating: (w - cum[i - 1]) / span))
    }

    private static func tangent(_ pts: [SIMD3<Float>], _ cum: [Float], _ total: Float, _ s: Float) -> SIMD3<Float> {
        let a = sample(pts, cum, total, s - 0.15), b = sample(pts, cum, total, s + 0.15)
        let d = b - a
        return simd_length(d) > 0.0001 ? normalize(d) : [0, 0, -1]
    }

    /// Axis-aligned bounds of the racing line.
    var bounds: (min: SIMD3<Float>, max: SIMD3<Float>) {
        var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude), hi = -lo
        for p in samples { lo = simd_min(lo, p); hi = simd_max(hi, p) }
        return (lo, hi)
    }
}

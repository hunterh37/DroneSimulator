import Foundation

/// Learns how raw `vgx`/`vgy` map onto forward/right by correlating them with the commanded
/// pitch/roll direction. Tests both body-frame and world-frame (power-on heading) hypotheses
/// and every axis swap and sign. Pure logic.
public struct AutoCalibrator: Equatable, Sendable {
    public static let minSamples = 12
    public static let minScore = 0.55

    /// score sums for [frame(0 body, 1 world)][swap][xSign][ySign]
    private var scores = [Double](repeating: 0, count: 16)
    public private(set) var samples = 0

    public init() {}

    public mutating func reset() { scores = .init(repeating: 0, count: 16); samples = 0 }

    /// headingBody: heading since takeoff (rad). yawRaw: raw yaw (rad) incl. power-on offset.
    public mutating func add(commanded s: DroneSticks, vgx: Int, vgy: Int, headingBody: Double, yawRaw: Double) {
        let p = Double(s.pitch), r = Double(s.roll)
        let mag = hypot(p, r)
        guard mag >= 0.2, abs(s.yaw) < 0.1, hypot(Double(vgx), Double(vgy)) >= 2 else { return }
        let e = SIMD2(p / mag, r / mag)
        let n = hypot(Double(vgx), Double(vgy))
        let raw = SIMD2(Double(vgx) / n, Double(vgy) / n)
        for frame in 0..<2 {
            // Expected direction in the frame the raw velocity is reported in.
            let th = frame == 0 ? 0 : yawRaw
            let ex = SIMD2(e.x * cos(th) - e.y * sin(th), e.x * sin(th) + e.y * cos(th))
            _ = headingBody
            for swap in 0..<2 {
                let a = swap == 1 ? raw.y : raw.x, b = swap == 1 ? raw.x : raw.y
                for xs in 0..<2 { for ys in 0..<2 {
                    let f = a * (xs == 0 ? 1 : -1), rt = b * (ys == 0 ? 1 : -1)
                    scores[frame * 8 + swap * 4 + xs * 2 + ys] += f * ex.x + rt * ex.y
                } }
            }
        }
        samples += 1
    }

    /// Best mapping once confident, nil otherwise. Keeps cmPerUnit and yawSign from `base`.
    public func result(base: VelocityCalibration) -> VelocityCalibration? {
        guard samples >= Self.minSamples else { return nil }
        // Prefer body frame on ties (no yaw change makes frames indistinguishable).
        var best = 0
        for i in 1..<16 where scores[i] > scores[best] + 1e-6 { best = i }
        guard scores[best] / Double(samples) >= Self.minScore else { return nil }
        var c = base
        c.bodyFrame = best < 8
        c.swapAxes = (best % 8) / 4 == 1
        c.xSign = (best % 4) / 2 == 0 ? 1 : -1
        c.ySign = best % 2 == 0 ? 1 : -1
        return c
    }
}

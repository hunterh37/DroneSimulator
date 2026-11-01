import Foundation
import simd

/// One Euro filter on a scalar. A convex low-pass, so a step input never overshoots.
public struct OneEuroFilter: Sendable {
    public var minCutoff: Float
    public var beta: Float
    public var derivativeCutoff: Float
    private var x: Float = 0
    private var dx: Float = 0
    private var lastTime: Double = 0
    private var primed = false

    public init(minCutoff: Float, beta: Float, derivativeCutoff: Float = 1.0) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.derivativeCutoff = derivativeCutoff
    }

    public mutating func reset(to value: Float, time: Double) {
        x = value
        dx = 0
        lastTime = time
        primed = true
    }

    public mutating func filter(_ value: Float, time: Double) -> Float {
        guard primed else {
            reset(to: value, time: time)
            return value
        }
        let dt = Float(max(time - lastTime, 1e-4))
        lastTime = time
        let rawDx = (value - x) / dt
        dx += Self.alpha(cutoff: derivativeCutoff, dt: dt) * (rawDx - dx)
        let cutoff = minCutoff + beta * abs(dx)
        x += Self.alpha(cutoff: cutoff, dt: dt) * (value - x)
        return x
    }

    static func alpha(cutoff: Float, dt: Float) -> Float {
        let tau = 1 / (2 * Float.pi * cutoff)
        return 1 / (1 + tau / dt)
    }
}

public struct OneEuroFilter3: Sendable {
    private var fx: OneEuroFilter
    private var fy: OneEuroFilter
    private var fz: OneEuroFilter

    public init(minCutoff: Float, beta: Float, derivativeCutoff: Float = 1.0) {
        let f = OneEuroFilter(minCutoff: minCutoff, beta: beta, derivativeCutoff: derivativeCutoff)
        fx = f; fy = f; fz = f
    }

    public mutating func reset(to v: SIMD3<Float>, time: Double) {
        fx.reset(to: v.x, time: time)
        fy.reset(to: v.y, time: time)
        fz.reset(to: v.z, time: time)
    }

    public mutating func filter(_ v: SIMD3<Float>, time: Double) -> SIMD3<Float> {
        SIMD3(fx.filter(v.x, time: time), fy.filter(v.y, time: time), fz.filter(v.z, time: time))
    }
}

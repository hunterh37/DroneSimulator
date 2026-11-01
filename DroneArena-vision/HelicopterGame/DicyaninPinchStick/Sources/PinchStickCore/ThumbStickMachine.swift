import Foundation
import simd

/// Thumb-on-index joystick. Thumb tip rests on the side of the index finger
/// (near the middle joint) and slides like a gamepad thumbstick.
public struct ThumbStickConfig: Sendable, Equatable {
    /// Thumb tip to index middle joint distance that engages the stick.
    public var engageDistance: Float = 0.028
    public var releaseDistance: Float = 0.045
    public var deadzone: Float = 0.003
    public var fullThrow: Float = 0.016
    public var expo: Float = 0.15
    public var minCutoff: Float = 3.0
    public var beta: Float = 0.1

    public init() {}

    var mapping: PinchStickConfig {
        var c = PinchStickConfig()
        c.deadzone = deadzone
        c.fullThrow = fullThrow
        c.expo = expo
        return c
    }
}

/// World positions of the joints the thumb stick reads.
public struct ThumbSample: Sendable, Equatable {
    public var thumbTip: SIMD3<Float>
    public var indexMiddle: SIMD3<Float>
    public var indexKnuckle: SIMD3<Float>
    public var wrist: SIMD3<Float>
    public var time: Double

    public init(thumbTip: SIMD3<Float>, indexMiddle: SIMD3<Float>, indexKnuckle: SIMD3<Float>,
                wrist: SIMD3<Float>, time: Double) {
        self.thumbTip = thumbTip
        self.indexMiddle = indexMiddle
        self.indexKnuckle = indexKnuckle
        self.wrist = wrist
        self.time = time
    }
}

/// `rotation` maps stick-local axes to world: +X right, +Y stick up, -Z forward (finger direction).
public struct ThumbStickState: Sendable, Equatable {
    public var held = false
    public var origin = SIMD3<Float>.zero
    public var rotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    public var knobPlane = SIMD2<Float>.zero
    public var output = SIMD2<Float>.zero

    public init() {}
}

public struct ThumbStickMachine: Sendable {
    public let side: StickSide
    public var config: ThumbStickConfig
    public private(set) var state = ThumbStickState()
    private var restLocal = SIMD2<Float>.zero
    private var filter: OneEuroFilter3

    public init(side: StickSide, config: ThumbStickConfig = ThumbStickConfig()) {
        self.side = side
        self.config = config
        filter = OneEuroFilter3(minCutoff: config.minCutoff, beta: config.beta)
    }

    /// Stick frame from the hand: forward along the index metacarpal, right horizontal.
    public static func frame(_ s: ThumbSample) -> (right: SIMD3<Float>, up: SIMD3<Float>, fwd: SIMD3<Float>)? {
        let f = s.indexKnuckle - s.wrist
        guard simd_length(f) > 1e-4 else { return nil }
        let fwd = simd_normalize(f)
        let r = simd_cross(fwd, SIMD3(0, 1, 0))
        guard simd_length(r) > 0.1 else { return nil }
        let right = simd_normalize(r)
        return (right, simd_cross(right, fwd), fwd)
    }

    @discardableResult
    public mutating func update(sample: ThumbSample?) -> ThumbStickState {
        guard let s = sample, let f = Self.frame(s) else { return release() }
        let d = simd_distance(s.thumbTip, s.indexMiddle)
        if !state.held {
            guard d < config.engageDistance else { return state }
            filter.reset(to: s.thumbTip - s.indexMiddle, time: s.time)
        } else if d > config.releaseDistance {
            return release()
        }
        let rel = filter.filter(s.thumbTip - s.indexMiddle, time: s.time)
        let local = SIMD2(simd_dot(rel, f.right), simd_dot(rel, f.fwd))
        if !state.held { restLocal = local }
        state.held = true
        let knob = StickMapping.clampKnob(local - restLocal, config: config.mapping)
        state.knobPlane = knob
        state.output = StickMapping.map(local - restLocal, config: config.mapping)
        state.origin = s.indexMiddle + f.right * restLocal.x + f.fwd * restLocal.y
        state.rotation = simd_quatf(simd_float3x3(columns: (f.right, f.up, -f.fwd)))
        return state
    }

    private mutating func release() -> ThumbStickState {
        state.held = false
        state.output = .zero
        state.knobPlane = .zero
        return state
    }
}

public enum StickMode: String, Sendable, Equatable, CaseIterable {
    case pinch, thumb
}

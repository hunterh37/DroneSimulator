import Foundation
import simd

public enum StickSide: Sendable, Equatable {
    case left, right
}

public struct PinchStickConfig: Sendable, Equatable {
    public var engageDistance: Float = 0.015
    public var releaseDistance: Float = 0.025
    public var deadzone: Float = 0.012
    public var fullThrow: Float = 0.045
    public var expo: Float = 0.15
    public var minCutoff: Float = 1.0
    public var beta: Float = 0.02
    public var derivativeCutoff: Float = 1.0

    public init() {}
}

/// Thumb and index fingertip positions in world meters, plus a monotonic timestamp in seconds.
public struct PinchSample: Sendable, Equatable {
    public var thumbTip: SIMD3<Float>
    public var indexTip: SIMD3<Float>
    public var time: Double

    public init(thumbTip: SIMD3<Float>, indexTip: SIMD3<Float>, time: Double) {
        self.thumbTip = thumbTip
        self.indexTip = indexTip
        self.time = time
    }

    public var distance: Float { simd_distance(thumbTip, indexTip) }
    public var pinchPoint: SIMD3<Float> { (thumbTip + indexTip) * 0.5 }
}

/// Result of one update. `knobPlane` is the clamped pinch offset in meters:
/// x = right of the grab frame, y = up (left stick) or forward (right stick).
public struct PinchStickState: Sendable, Equatable {
    public var held = false
    public var origin = SIMD3<Float>.zero
    public var yaw: Float = 0
    public var output = SIMD2<Float>.zero
    public var knobPlane = SIMD2<Float>.zero

    public init() {}
}

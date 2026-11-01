import Foundation
import simd

public enum StickMapping {
    /// Radial deadzone, rescale to 0...1 at full throw, expo blend, unit-circle clamp.
    public static func map(_ v: SIMD2<Float>, config: PinchStickConfig) -> SIMD2<Float> {
        let r = simd_length(v)
        guard r > config.deadzone, r > 0 else { return .zero }
        let span = max(config.fullThrow - config.deadzone, 1e-6)
        let m = min((r - config.deadzone) / span, 1)
        let curved = (1 - config.expo) * m + config.expo * m * m * m
        return v / r * min(curved, 1)
    }

    /// Offset limited to the full-throw circle, in meters.
    public static func clampKnob(_ v: SIMD2<Float>, config: PinchStickConfig) -> SIMD2<Float> {
        let r = simd_length(v)
        guard r > config.fullThrow, r > 0 else { return v }
        return v / r * config.fullThrow
    }

    /// Yaw (radians about +Y) of a head forward vector. Forward is -Z at yaw 0.
    public static func yaw(forward: SIMD3<Float>) -> Float {
        atan2(-forward.x, -forward.z)
    }

    /// World offset into the head-yawed frame: x = right, y = up, z = forward.
    public static func localize(_ d: SIMD3<Float>, yaw: Float) -> SIMD3<Float> {
        let s = sin(yaw), c = cos(yaw)
        let right = d.x * c - d.z * s
        let forward = -d.x * s - d.z * c
        return SIMD3(right, d.y, forward)
    }

    /// Left: x yaw, y throttle. Right: x roll, forward pitch.
    public static func plane(_ local: SIMD3<Float>, side: StickSide) -> SIMD2<Float> {
        switch side {
        case .left: return SIMD2(local.x, local.y)
        case .right: return SIMD2(local.x, local.z)
        }
    }
}

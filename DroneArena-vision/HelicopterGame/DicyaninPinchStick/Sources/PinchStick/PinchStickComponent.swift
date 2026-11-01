#if os(visionOS)
import RealityKit
import PinchStickCore

/// Written by the controller each update, consumed by `PinchStickSystem`.
public struct PinchStickComponent: Component {
    public var side: StickSide = .right
    public var held = false
    public var origin = SIMD3<Float>.zero
    public var yaw: Float = 0
    public var knobPlane = SIMD2<Float>.zero
    public var outsideDeadzone = false
    public var visible = true
    public var alpha: Float = 0

    var parts: PinchStickParts?

    public init() {}
}

/// Prebuilt child entities of one stick container.
struct PinchStickParts {
    let ring: Entity
    let deadRing: Entity
    let knob: Entity
    let tether: Entity
}
#endif

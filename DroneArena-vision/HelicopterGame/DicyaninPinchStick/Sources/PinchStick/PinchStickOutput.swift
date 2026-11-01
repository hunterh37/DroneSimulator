import Foundation
import simd
import PinchStickCore

/// Per-update stick state. Axes are -1...1 inside the unit circle.
/// Left: x yaw, y throttle. Right: x roll, y pitch (forward positive).
public struct PinchStickOutput: Sendable, Equatable {
    public var left: SIMD2<Float>
    public var right: SIMD2<Float>
    public var leftHeld: Bool
    public var rightHeld: Bool

    public static let zero = PinchStickOutput(left: .zero, right: .zero, leftHeld: false, rightHeld: false)

    public init(left: SIMD2<Float>, right: SIMD2<Float>, leftHeld: Bool, rightHeld: Bool) {
        self.left = left
        self.right = right
        self.leftHeld = leftHeld
        self.rightHeld = rightHeld
    }
}

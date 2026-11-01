//
//  VirtualJoystickBridge.swift
//  DicyaninVirtualJoystick
//
//  The single integration seam between this package and its host app.
//
//  The 3D gamepad / joystick rig used to reach directly into app-level singletons:
//   • ControlSchemeConfig          — to know whether the rig was the active scheme,
//   • GameContext.shared.handGesture — to read per-hand pinch positions, and
//   • DualThumbController.shared    — to push the resulting stick input downstream.
//
//  To keep the package standalone (no dependency back on the app or on
//  DicyaninThumbController), those three couplings are replaced by injectable
//  closures the host wires once at launch. If the host wires nothing, the rig is
//  simply inert (`isEnabled` defaults to false).
//

import simd

/// Per-hand pinch positions in scene/world space, used to drive two-handed grabs.
/// A `nil` field means that hand is not currently pinching (or isn't tracked).
public struct VirtualJoystickHandPinch: Sendable {
    public var left: SIMD3<Float>?
    public var right: SIMD3<Float>?
    public init(left: SIMD3<Float>?, right: SIMD3<Float>?) {
        self.left = left
        self.right = right
    }
}

/// Normalized two-stick output produced by `Gamepad3DSystem` each frame. The host
/// forwards this into whatever drives its movement (e.g. DualThumbController).
public struct VirtualJoystickInput: Sendable {
    public var leftDirection: SIMD3<Float>
    public var leftMagnitude: Float
    public var leftActive: Bool
    public var rightDirection: SIMD3<Float>
    public var rightMagnitude: Float
    public var rightActive: Bool
    public init(leftDirection: SIMD3<Float>, leftMagnitude: Float, leftActive: Bool,
                rightDirection: SIMD3<Float>, rightMagnitude: Float, rightActive: Bool) {
        self.leftDirection = leftDirection
        self.leftMagnitude = leftMagnitude
        self.leftActive = leftActive
        self.rightDirection = rightDirection
        self.rightMagnitude = rightMagnitude
        self.rightActive = rightActive
    }
}

/// Host-configured hooks the joystick package calls into. Set these once at app
/// launch (before the immersive scene runs).
public enum VirtualJoystickBridge {

    /// Whether the world-anchored joystick rig is the active control scheme.
    /// `Gamepad3DSystem` early-outs every frame when this returns false.
    /// Accessed only from the RealityKit simulation update (single-threaded).
    public nonisolated(unsafe) static var isEnabled: () -> Bool = { false }

    /// Supplies the current per-hand pinch positions for two-handed grab
    /// resolution on device. Return `nil` when no hand tracking is available
    /// (e.g. the Simulator, where the SwiftUI drag gesture drives grabs instead).
    /// Invoked on the main actor from within the simulation update.
    @MainActor public static var handPinchProvider: () -> VirtualJoystickHandPinch? = { nil }

    /// Receives the normalized stick output each frame so the host can route it
    /// into its movement pipeline. Called from the simulation update.
    public nonisolated(unsafe) static var output: (VirtualJoystickInput) -> Void = { _ in }
}

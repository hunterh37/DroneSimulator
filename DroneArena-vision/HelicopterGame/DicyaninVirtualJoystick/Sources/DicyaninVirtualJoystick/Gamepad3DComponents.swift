//
//  Gamepad3DComponents.swift
//  HelicopterGame
//
//  Components for the world-anchored 3D gamepad with two physics joysticks.
//
//  Hierarchy per joystick:
//
//      socket (fixed visual ring on the gamepad body)
//      pivot  <-- Gamepad3DJoystickComponent  (rotates about its local origin = the joint base)
//        └─ shaft  (visual stick)
//             └─ head  <-- Gamepad3DHeadComponent + InputTargetComponent + CollisionComponent
//
//  The pivot's local origin sits exactly at the base of the stick, so rotating
//  the pivot tilts the whole stick around that point — that pivot point is the
//  "joint anchor at the base". The head is what the user physically grabs; it
//  carries the collision + input target so hand gestures can push it around.
//

import RealityKit
import simd

// MARK: - Joystick (pivot) component

public struct Gamepad3DJoystickComponent: Component {

    public enum Side: String, Sendable {
        case left
        case right
    }

    /// Which physical stick this is. Drives which half of the drone-control
    /// pipeline it feeds (left = throttle/yaw, right = pitch/roll).
    public var side: Side

    /// Distance from the pivot base to the head, in meters. Used to convert a
    /// grabbed head position into a tilt angle.
    public var stickLength: Float

    /// Maximum tilt away from vertical, in radians. Full deflection == magnitude 1.
    public var maxTilt: Float

    /// Normalized deadzone (0...1) below which the stick reports no input.
    public var deadzone: Float

    // MARK: Spring-joint physics state
    /// Current tilt angles in radians: x = pitch (about local X), y = roll (about local Z).
    public var tilt: SIMD2<Float> = .zero
    /// Angular velocity of the tilt (radians/sec) for the spring-damper integrator.
    public var angularVelocity: SIMD2<Float> = .zero

    /// Spring stiffness used to return the stick to center when released.
    public var returnStiffness: Float
    /// Spring stiffness used to chase the hand while grabbed (stiffer = tighter follow).
    public var grabStiffness: Float
    /// Damping applied to angular velocity (higher = less overshoot/wobble).
    public var damping: Float

    // MARK: Grab state (written by the drag gesture, read by the system)
    /// True while a hand is dragging the head.
    public var isGrabbed: Bool = false
    /// The grabbed target expressed in the pivot's local space. The system tilts
    /// the stick so its head chases this point. `nil` when not grabbed.
    public var grabTargetLocal: SIMD3<Float>? = nil

    public init(side: Side,
                stickLength: Float = 0.05,
                maxTilt: Float = .pi / 5.0, // 36°
                deadzone: Float = 0.06,
                returnStiffness: Float = 220.0,
                grabStiffness: Float = 900.0,
                damping: Float = 22.0) {
        self.side = side
        self.stickLength = stickLength
        self.maxTilt = maxTilt
        self.deadzone = deadzone
        self.returnStiffness = returnStiffness
        self.grabStiffness = grabStiffness
        self.damping = damping
    }
}

// MARK: - Head (grab target) component

/// Lightweight tag placed on the grabbable head sphere so the drag gesture can
/// target it. Holds a reference back to its pivot so the gesture can write the
/// grab target onto the `Gamepad3DJoystickComponent`.
public struct Gamepad3DHeadComponent: Component {
    public weak var pivot: Entity?
    public init(pivot: Entity? = nil) {
        self.pivot = pivot
    }
}

// MARK: - Button component

/// Tag placed on a pressable button (e.g. the pillar stand's missile trigger).
/// The action tells the gesture/handler what the button should do; `restY` and
/// `pressDepth` let the press animation pop the cap down and back.
public struct Gamepad3DButtonComponent: Component {

    public enum Action: String, Sendable {
        /// Fire a missile from the player drone (reuses the existing fire path).
        case fireMissile
        /// Toggle the floating sci-fi hologram minimap above the pillar deck.
        case toggleHologram
    }

    public var action: Action
    /// Which weapon slot this button fires (1 or 2). Ignored for non-fire actions.
    public var slot: Int
    /// Local Y of the button cap at rest, so it can spring back after a press.
    public var restY: Float
    /// How far down (meters) the cap travels while pressed.
    public var pressDepth: Float

    public init(action: Action = .fireMissile, slot: Int = 1, restY: Float = 0, pressDepth: Float = 0.006) {
        self.action = action
        self.slot = slot
        self.restY = restY
        self.pressDepth = pressDepth
    }
}

// MARK: - Pillar base (drag handle) component

/// Tag placed on the pillar stand's floor foot so a drag gesture can pick it up
/// and reposition the WHOLE stand. Holds a reference to the pillar root that
/// should actually be moved (the foot is just the grab handle).
public struct GamepadPillarBaseComponent: Component {
    public weak var root: Entity?
    public init(root: Entity? = nil) {
        self.root = root
    }
}

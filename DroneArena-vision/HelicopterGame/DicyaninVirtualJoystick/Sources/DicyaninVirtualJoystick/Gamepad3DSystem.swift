//
//  Gamepad3DSystem.swift
//  HelicopterGame
//
//  Drives the 3D gamepad joysticks:
//   1. Spring-joint physics — each stick pivots about its base. While grabbed it
//      chases the hand; on release a critically-ish damped spring snaps it back
//      to center.
//   2. Tilt readout — the resulting tilt is normalized into a stick direction +
//      magnitude and pushed into DualThumbController via setVirtualJoystickInput,
//      i.e. the EXACT same path the simulator joysticks and (ultimately) the
//      drone-movement system already consume. No drone code has to change.
//
//  Only active when ControlSchemeConfig.useGamepad3D is true.
//

import RealityKit
import simd
import Foundation

@MainActor
public final class Gamepad3DSystem: System {

    private static let query = EntityQuery(where: .has(Gamepad3DJoystickComponent.self))
    private static let headQuery = EntityQuery(where: .has(Gamepad3DHeadComponent.self))

    /// Radius (meters) within which a pinching hand can latch onto a joystick head.
    private static let grabRadius: Float = 0.07

    // Which pivot each hand currently owns. Tracked across frames so a hand keeps
    // its stick until it releases — this is what lets BOTH hands grab BOTH sticks
    // at once (one pinch per hand), instead of a single SwiftUI DragGesture only
    // ever following one hand.
    private weak var leftOwnedPivot: Entity?
    private weak var rightOwnedPivot: Entity?

    public required init(scene: Scene) {}

    public func update(context: SceneUpdateContext) {
        guard VirtualJoystickBridge.isEnabled() else { return }

        // Resolve two-handed grabs from hand tracking BEFORE the spring loop reads
        // each stick's grab state.
        resolveHandGrabs(context: context)

        let dt = min(Float(context.deltaTime), 1.0 / 30.0) // clamp for stability

        // Accumulated per-stick output for this frame.
        var leftDir = SIMD3<Float>.zero,  leftMag: Float = 0,  leftActive = false
        var rightDir = SIMD3<Float>.zero, rightMag: Float = 0, rightActive = false

        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var comp = entity.components[Gamepad3DJoystickComponent.self] else { continue }

            // --- Determine the spring target (tilt angles the stick wants to be at) ---
            var targetTilt = SIMD2<Float>.zero
            let stiffness: Float

            if comp.isGrabbed, let target = comp.grabTargetLocal {
                targetTilt = Self.tiltAngles(forLocalTarget: target,
                                             stickLength: comp.stickLength,
                                             maxTilt: comp.maxTilt)
                stiffness = comp.grabStiffness
            } else {
                // Released -> return to center.
                targetTilt = .zero
                stiffness = comp.returnStiffness
            }

            // --- Integrate the angular spring-damper (the "joint" behavior) ---
            // a = k * (target - x) - c * v
            let accel = stiffness * (targetTilt - comp.tilt) - comp.damping * comp.angularVelocity
            comp.angularVelocity += accel * dt
            comp.tilt += comp.angularVelocity * dt

            // Clamp to the joint's range of motion.
            comp.tilt.x = max(-comp.maxTilt, min(comp.maxTilt, comp.tilt.x))
            comp.tilt.y = max(-comp.maxTilt, min(comp.maxTilt, comp.tilt.y))

            // --- Apply the tilt to the pivot's orientation ---
            let pitchQ = simd_quatf(angle: comp.tilt.x, axis: SIMD3<Float>(1, 0, 0)) // tips forward/back (Z)
            let rollQ  = simd_quatf(angle: comp.tilt.y, axis: SIMD3<Float>(0, 0, 1)) // tips left/right (X)
            entity.orientation = pitchQ * rollQ

            entity.components.set(comp)

            // --- Read out normalized stick input ---
            // Match the existing simulator-joystick convention exactly (see
            // InputRouter.updateLeft/RightJoystickInput): x = lateral (right +),
            // y = forward/back, and the LEFT stick negates y while the right does not.
            // Both axes are negated here so the stick reports the SAME sign the
            // simulator joysticks do: pushing the head forward/up flies the drone
            // forward/up, pushing right moves right. (Without this the head's tilt
            // direction is reported opposite to the drone-movement convention,
            // which flew everything backwards — down for up, left for right.)
            let horizontal = clampUnit(comp.tilt.y / comp.maxTilt)
            let vertical   = clampUnit(-comp.tilt.x / comp.maxTilt)

            var magnitude = sqrt(horizontal * horizontal + vertical * vertical)
            magnitude = min(magnitude, 1.0)

            // Only a stick that's actively grabbed contributes input. The return
            // spring is PURELY VISUAL — once released the stick still animates back
            // to center, but its ringing/overshoot must not be fed to the drone or
            // those transients integrate into permanent position drift ("the drone
            // keeps slightly moving after I let go"). This mirrors the mobile
            // joysticks, which hard-zero the instant the thumb lifts.
            let active = comp.isGrabbed && magnitude > comp.deadzone

            // Route each physical stick to the drone channel it should drive.
            // The consumer (DualThumbControlledComponent / InputRouter) defines:
            //   leftDirection  channel -> height (throttle, y) + yaw (x)
            //   rightDirection channel -> pitch (forward/back, y) + roll (strafe, x)
            // So:
            //   BLUE  (.left  side)  -> height + yaw     == the leftDirection channel
            //   ORANGE(.right side)  -> pitch + roll     == the rightDirection channel
            // The y-negation belongs to the DESTINATION channel, not the physical
            // side: the leftDirection channel negates y, the rightDirection one
            // does not (matching InputRouter's (x,-y) vs (x,y) convention).
            let drivesPosition = comp.side == .right            // orange -> position (pitch/roll)
            // Blue (height channel) must climb when pushed UP, so do NOT negate it.
            // Orange (position channel) is consumed as (x, -y) downstream, so negate
            // here to keep push-forward == fly-forward.
            let y = drivesPosition ? -vertical : vertical
            let direction = active ? SIMD3<Float>(horizontal, y, 0) : .zero
            let reportedMag = active ? magnitude : 0

            if drivesPosition {
                // rightDirection channel == position (pitch/roll). Orange must NOT
                // touch height — it lives only on the leftDirection channel.
                rightDir = direction; rightMag = reportedMag; rightActive = active
            } else {
                // leftDirection channel == height (throttle) + yaw
                leftDir = direction; leftMag = reportedMag; leftActive = active
            }
        }

        // Hand the normalized stick output to the host, which routes it into its
        // movement pipeline (same entry point the simulator joysticks use).
        VirtualJoystickBridge.output(
            VirtualJoystickInput(
                leftDirection: leftDir,
                leftMagnitude: leftMag,
                leftActive: leftActive,
                rightDirection: rightDir,
                rightMagnitude: rightMag,
                rightActive: rightActive
            )
        )
    }

    // MARK: - Two-handed grab resolution

    /// Latch each pinching hand onto the nearest joystick head and feed its world
    /// position into that stick's `grabTargetLocal`. Each hand owns its stick
    /// independently, so the left and right sticks can be grabbed and driven at
    /// the same time — the fix for "only one joystick can be grabbed at a time".
    private func resolveHandGrabs(context: SceneUpdateContext) {
        // In the Simulator there's no hand tracking — joystick grabbing is handled
        // by the SwiftUI DragGesture instead (see Gamepad3DGestureExtensions).
#if os(visionOS) && !targetEnvironment(simulator)
        // Snapshot the grabbable heads and their current world positions.
        var heads: [(pivot: Entity, pos: SIMD3<Float>)] = []
        for head in context.entities(matching: Self.headQuery, updatingSystemWhen: .rendering) {
            guard let pivot = head.components[Gamepad3DHeadComponent.self]?.pivot else { continue }
            heads.append((pivot, head.position(relativeTo: nil)))
        }

        // Hand tracking lives on the main actor; the simulation update runs on the
        // main thread, so reading it here is safe.
        MainActor.assumeIsolated {
            let pinch = VirtualJoystickBridge.handPinchProvider()
            let leftPinch = pinch?.left
            let rightPinch = pinch?.right

            // Resolve each hand. Pass the other hand's owned pivot so two hands
            // can't both fight over the same stick.
            leftOwnedPivot = resolveHand(pinchPos: leftPinch,
                                         owned: leftOwnedPivot,
                                         claimedByOtherHand: rightOwnedPivot,
                                         heads: heads)
            rightOwnedPivot = resolveHand(pinchPos: rightPinch,
                                          owned: rightOwnedPivot,
                                          claimedByOtherHand: leftOwnedPivot,
                                          heads: heads)
        }
#endif
    }

    /// Returns the pivot this hand owns after processing the frame (nil if not grabbing).
    private func resolveHand(pinchPos: SIMD3<Float>?,
                             owned: Entity?,
                             claimedByOtherHand: Entity?,
                             heads: [(pivot: Entity, pos: SIMD3<Float>)]) -> Entity? {
        guard let pinch = pinchPos else {
            // Not pinching: release whatever this hand held.
            if let pivot = owned { setGrab(pivot, grabbed: false, target: nil) }
            return nil
        }

        // Claim a head on the first pinch frame; afterwards stay latched to it
        // (sticky) until release, even if the hand drifts toward the other stick.
        var ownedPivot = owned
        if ownedPivot == nil {
            var bestDistance = Self.grabRadius
            for head in heads {
                if let other = claimedByOtherHand, head.pivot.id == other.id { continue }
                let distance = simd_distance(head.pos, pinch)
                if distance < bestDistance {
                    bestDistance = distance
                    ownedPivot = head.pivot
                }
            }
        }

        if let pivot = ownedPivot {
            // Express the hand position as a vector from the joint base in the
            // gamepad BODY frame (pivot's unrotated parent) — same convention the
            // old drag gesture used so the spring physics behave identically.
            let bodyPos = (pivot.parent ?? pivot).convert(position: pinch, from: nil)
            setGrab(pivot, grabbed: true, target: bodyPos - pivot.position)
        }
        return ownedPivot
    }

    private func setGrab(_ pivot: Entity, grabbed: Bool, target: SIMD3<Float>?) {
        guard var comp = pivot.components[Gamepad3DJoystickComponent.self] else { return }
        comp.isGrabbed = grabbed
        comp.grabTargetLocal = target
        pivot.components.set(comp)
    }

    /// Convert a grab target (vector from the joint base, in the gamepad body
    /// frame) into independent pitch/roll tilt angles.
    ///
    /// We derive each axis purely from the hand's HORIZONTAL offset in the body's
    /// XZ plane and ignore the vertical (Y) component. This keeps the two axes
    /// fully decoupled: pushing the head straight forward produces pitch ONLY
    /// (no roll), and pushing it sideways produces roll ONLY. Using the full 3D
    /// direction instead (atan2 dividing by Y) cross-couples the axes whenever
    /// the hand isn't cleanly above the base, which made one stick lift AND
    /// rotate the drone at the same time.
    private static func tiltAngles(forLocalTarget target: SIMD3<Float>,
                                   stickLength: Float,
                                   maxTilt: Float) -> SIMD2<Float> {
        let len = max(stickLength, 1e-4)
        // Normalized horizontal deflection of the head, clamped to the stick's reach.
        let fz = max(-1.0, min(1.0, target.z / len)) // forward/back
        let fx = max(-1.0, min(1.0, target.x / len)) // left/right

        // head_z = sin(pitch) and head_x = -sin(roll), so invert via asin.
        let pitch = asin(fz)   // rotation about X
        let roll  = asin(-fx)  // rotation about Z
        return SIMD2<Float>(
            max(-maxTilt, min(maxTilt, pitch)),
            max(-maxTilt, min(maxTilt, roll))
        )
    }
}

private func clampUnit(_ v: Float) -> Float { max(-1.0, min(1.0, v)) }

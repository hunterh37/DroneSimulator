//
//  Gamepad3DEntity.swift
//  HelicopterGame
//
//  A world-anchored 3D gamepad with two physical joysticks.
//
//  The body is fixed in place (it does NOT move with the drone or the head).
//  Each joystick head is grabbable (collision + input target) and tilts about a
//  spring joint at its base. Gamepad3DSystem reads the tilt and drives the drone.
//

import RealityKit
import simd
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public final class Gamepad3DEntity: Entity {

    /// Convenience factory. `position` is where the gamepad body sits in world
    /// space (relative to its parent). Default is a comfortable seated reach.
    public static func make(at position: SIMD3<Float> = SIMD3<Float>(0, 0.85, -0.55)) -> Gamepad3DEntity {
        let pad = Gamepad3DEntity()
        pad.build()
        pad.position = position
        return pad
    }

    private func build() {
        name = "Gamepad3D"

        // --- Gamepad body: a composed game-controller silhouette (fixed) ---
        // Instead of one flat rectangle we assemble a recognizable pad shape:
        //   • a rounded central body,
        //   • two grips that splay outward/forward (the "horns"),
        //   • rounded caps on the grip ends,
        //   • two shoulder bumpers across the back edge.
        // All pieces are parented to a single GamepadBody container so the
        // joystick rig below stays anchored to the same local frame as before.
        let bodyThickness: Float = 0.03
        let topY = bodyThickness / 2.0

        let bodyContainer = Entity()
        bodyContainer.name = "GamepadBody"
        addChild(bodyContainer)

        let bodyMat = Gamepad3DParts.bodyMaterial()

        // Central body — wide rounded slab through the middle.
        let center = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(0.20, bodyThickness, 0.15), cornerRadius: 0.03),
            materials: [bodyMat]
        )
        center.name = "GamepadBodyCenter"
        bodyContainer.addChild(center)

        // Grips — elongated rounded boxes splayed out to each side and toward
        // the user, like the handles of a console controller.
        let gripSize = SIMD3<Float>(0.058, bodyThickness, 0.165)
        let gripSplay: Float = .pi / 7.0   // ~25° outward
        for side: Float in [-1, 1] {
            let grip = ModelEntity(
                mesh: .generateBox(size: gripSize, cornerRadius: 0.026),
                materials: [bodyMat]
            )
            grip.name = side < 0 ? "GamepadGripLeft" : "GamepadGripRight"
            grip.position = SIMD3<Float>(side * 0.10, 0, 0.055)
            grip.orientation = simd_quatf(angle: side * gripSplay, axis: SIMD3<Float>(0, 1, 0))
            bodyContainer.addChild(grip)

            // Rounded cap at the end of each grip.
            let cap = ModelEntity(
                mesh: .generateSphere(radius: gripSize.x / 2.0),
                materials: [bodyMat]
            )
            cap.position = SIMD3<Float>(0, 0, gripSize.z / 2.0)
            cap.scale = SIMD3<Float>(1.0, bodyThickness / gripSize.x, 1.0)
            grip.addChild(cap)
        }

        // Shoulder bumpers — two small rounded bars along the back top edge.
        for side: Float in [-1, 1] {
            let bumper = ModelEntity(
                mesh: .generateBox(size: SIMD3<Float>(0.05, 0.014, 0.02), cornerRadius: 0.007),
                materials: [Gamepad3DParts.shaftMaterial()]
            )
            bumper.name = side < 0 ? "GamepadBumperLeft" : "GamepadBumperRight"
            bumper.position = SIMD3<Float>(side * 0.07, topY, -0.075)
            bodyContainer.addChild(bumper)
        }

        // Two sticks, offset left/right on the body. Built from the shared rig
        // so they match the pillar variant exactly.
        let xOffset: Float = 0.06
        Gamepad3DParts.addJoystick(to: self, side: .left,  at: SIMD3<Float>(-xOffset, topY, 0))
        Gamepad3DParts.addJoystick(to: self, side: .right, at: SIMD3<Float>( xOffset, topY, 0))
    }
}

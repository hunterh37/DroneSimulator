//
//  Gamepad3DParts.swift
//  HelicopterGame
//
//  Shared builders for the 3D gamepad family (flat pad + pillar stand).
//
//  The joystick rig (socket ring → pivot → shaft → grabbable head) is identical
//  no matter what it's mounted on, so it lives here once and both
//  Gamepad3DEntity and GamepadPillarEntity reuse it. This guarantees the pillar's
//  sticks behave EXACTLY like the working flat-pad sticks: same component, same
//  spring-joint physics, same gesture target.
//

import RealityKit
import simd
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum Gamepad3DParts {

    // MARK: - Joystick rig (reused verbatim by every variant)

    /// Builds one joystick (socket + pivot + shaft + grabbable head) and parents
    /// it under `parent`, with the joint base at `base` in the parent's local
    /// space. Returns the pivot so callers can tweak it if needed.
    @discardableResult
    public static func addJoystick(to parent: Entity,
                                   side: Gamepad3DJoystickComponent.Side,
                                   at base: SIMD3<Float>,
                                   stickLength: Float = 0.05,
                                   headRadius: Float = 0.018) -> Entity {
        // Fixed socket ring sitting on the deck (does not tilt).
        let socket = ModelEntity(
            mesh: .generateCylinder(height: 0.012, radius: 0.026),
            materials: [socketMaterial()]
        )
        socket.name = "Socket_\(side.rawValue)"
        socket.position = base
        parent.addChild(socket)

        // Pivot — local origin == joint base. Tilting this rotates the stick.
        let pivot = Entity()
        pivot.name = "Pivot_\(side.rawValue)"
        pivot.position = base
        pivot.components.set(Gamepad3DJoystickComponent(side: side, stickLength: stickLength))
        parent.addChild(pivot)

        // Shaft — a thin stick rising from the pivot base to the head.
        let shaft = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(0.01, stickLength, 0.01), cornerRadius: 0.004),
            materials: [shaftMaterial()]
        )
        shaft.name = "Shaft_\(side.rawValue)"
        shaft.position = SIMD3<Float>(0, stickLength / 2.0, 0)
        pivot.addChild(shaft)

        // Head — the grabbable knob at the top of the stick.
        let head = ModelEntity(
            mesh: .generateSphere(radius: headRadius),
            materials: [headMaterial(side: side)]
        )
        head.name = "Head_\(side.rawValue)"
        head.position = SIMD3<Float>(0, stickLength, 0)

        // Gesture collision: a slightly larger collision sphere makes it easy to grab.
        let grabRadius = headRadius * 1.6
        head.components.set(CollisionComponent(shapes: [.generateSphere(radius: grabRadius)]))
        head.components.set(InputTargetComponent())
        #if !os(macOS)
        head.components.set(HoverEffectComponent())  // hover highlight: visionOS/iOS only
        #endif
        head.components.set(Gamepad3DHeadComponent(pivot: pivot))

        pivot.addChild(head)
        return pivot
    }

    // MARK: - Fire button

    /// Builds a pressable round button (a domed cap recessed in a dark housing)
    /// wired with `Gamepad3DButtonComponent`. Tapping it is handled in
    /// ImmersiveView, which routes to the existing missile-fire path for `slot`.
    public static func makeFireButton(at position: SIMD3<Float>,
                                      slot: Int = 1,
                                      tint: UIColor = .systemRed,
                                      radius: Float = 0.02,
                                      action: Gamepad3DButtonComponent.Action = .fireMissile) -> Entity {
        let housingHeight: Float = 0.01

        let container = Entity()
        container.name = "FireButton_slot\(slot)"
        container.position = position

        // Dark housing collar the cap sits in.
        let housing = ModelEntity(
            mesh: .generateCylinder(height: housingHeight, radius: radius * 1.4),
            materials: [socketMaterial()]
        )
        housing.name = "FireButtonHousing_slot\(slot)"
        container.addChild(housing)

        // The round (domed) pressable cap — a sphere squashed into a button dome.
        let cap = ModelEntity(
            mesh: .generateSphere(radius: radius),
            materials: [buttonMaterial(tint: tint)]
        )
        cap.name = "FireButtonCap_slot\(slot)"
        cap.scale = SIMD3<Float>(1.0, 0.55, 1.0)   // flatten into a dome
        let restY = housingHeight / 2.0 + radius * 0.25
        cap.position = SIMD3<Float>(0, restY, 0)

        // Easy-to-hit press target.
        cap.components.set(CollisionComponent(shapes: [.generateSphere(radius: radius * 1.5)]))
        cap.components.set(InputTargetComponent())
        #if !os(macOS)
        cap.components.set(HoverEffectComponent())  // hover highlight: visionOS/iOS only
        #endif
        cap.components.set(Gamepad3DButtonComponent(action: action, slot: slot, restY: restY, pressDepth: 0.006))

        container.addChild(cap)
        return container
    }

    // MARK: - Materials

    public static func bodyMaterial() -> RealityKit.Material {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: UIColor(white: 0.12, alpha: 1.0))
        m.roughness = .init(floatLiteral: 0.5)
        m.metallic = .init(floatLiteral: 0.6)
        return m
    }

    public static func socketMaterial() -> RealityKit.Material {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: UIColor(white: 0.05, alpha: 1.0))
        m.roughness = .init(floatLiteral: 0.8)
        m.metallic = .init(floatLiteral: 0.2)
        return m
    }

    public static func shaftMaterial() -> RealityKit.Material {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: UIColor(white: 0.2, alpha: 1.0))
        m.roughness = .init(floatLiteral: 0.4)
        m.metallic = .init(floatLiteral: 0.7)
        return m
    }

    public static func headMaterial(side: Gamepad3DJoystickComponent.Side) -> RealityKit.Material {
        var m = PhysicallyBasedMaterial()
        let tint: UIColor = side == .left ? .systemBlue : .systemOrange
        m.baseColor = .init(tint: tint)
        m.roughness = .init(floatLiteral: 0.35)
        m.metallic = .init(floatLiteral: 0.1)
        return m
    }

    public static func buttonMaterial(tint: UIColor = .systemRed) -> RealityKit.Material {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: tint)
        m.roughness = .init(floatLiteral: 0.3)
        m.metallic = .init(floatLiteral: 0.1)
        m.emissiveColor = .init(color: tint)
        m.emissiveIntensity = 0.4
        return m
    }
}

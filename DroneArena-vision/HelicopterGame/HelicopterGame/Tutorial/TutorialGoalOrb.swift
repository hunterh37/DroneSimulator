//
//  TutorialGoalOrb.swift
//  HelicopterGame
//
//  A glowing white "fly here" target marker used by tutorial steps. It's a
//  bright emissive core wrapped in a soft translucent halo, with a point light
//  for a little real bloom onto nearby geometry. `update(deltaTime:)` drives a
//  gentle breathing pulse; the controller forwards each tick to it.
//

#if os(visionOS)
import RealityKit
import UIKit
import simd

public final class TutorialGoalOrb: Entity {

    private let core: ModelEntity
    private let halo: ModelEntity
    private let baseRadius: Float
    private var elapsed: TimeInterval = 0

    public required init() {
        baseRadius = 0.07
        core = TutorialGoalOrb.makeCore(radius: baseRadius)
        halo = TutorialGoalOrb.makeHalo(radius: baseRadius * 1.7)
        super.init()

        addChild(halo)
        addChild(core)

        // A soft white light so the orb actually casts glow into the room.
        let glow = PointLight()
        glow.light.color = .white
        glow.light.intensity = 1500
        glow.light.attenuationRadius = 0.6
        addChild(glow)

        // Single opacity knob the controller can fade for spawn/despawn.
        components.set(OpacityComponent(opacity: 1))
    }

    /// Breathing pulse: the halo swells and softens, the core gently bobs in
    /// scale. Purely cosmetic — completion is driven by the drone, not the orb.
    public func update(deltaTime: TimeInterval) {
        elapsed += deltaTime
        let t = Float(elapsed)
        let haloPulse = 1.0 + 0.18 * sin(t * 2.6)
        halo.scale = SIMD3<Float>(repeating: haloPulse)
        let corePulse = 1.0 + 0.06 * sin(t * 4.0)
        core.scale = SIMD3<Float>(repeating: corePulse)
    }

    // MARK: - Build

    private static func makeCore(radius: Float) -> ModelEntity {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: .white)
        m.emissiveColor = .init(color: .white)
        m.emissiveIntensity = 3.0
        m.roughness = .init(floatLiteral: 1.0)
        m.metallic = .init(floatLiteral: 0.0)
        return ModelEntity(mesh: .generateSphere(radius: radius), materials: [m])
    }

    private static func makeHalo(radius: Float) -> ModelEntity {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: .white)
        m.emissiveColor = .init(color: .white)
        m.emissiveIntensity = 1.2
        m.blending = .transparent(opacity: .init(floatLiteral: 0.16))
        m.faceCulling = .none
        return ModelEntity(mesh: .generateSphere(radius: radius), materials: [m])
    }
}
#endif

//
//  CrateWorldBuilder.swift
//  HelicopterGame
//
//  Procedural meshes for Fold Freight: crates, Relay Gates, claw rig,
//  ceiling rifts, wall props, 3D score pops. Meshes are cached and shared.
//

import RealityKit
import UIKit
import simd

@MainActor
enum CrateWorldBuilder {
    static let crateSize: Float = 0.15
    static let gateRadius: Float = 0.17

    private static var meshCache: [String: MeshResource] = [:]

    private static func mesh(_ key: String, _ make: () -> MeshResource) -> MeshResource {
        if let m = meshCache[key] { return m }
        let m = make()
        meshCache[key] = m
        return m
    }

    static func glow(_ color: UIColor, _ alpha: CGFloat = 1) -> UnlitMaterial {
        var m = UnlitMaterial(color: color.withAlphaComponent(alpha))
        if alpha < 1 { m.blending = .transparent(opacity: .init(floatLiteral: Float(alpha))) }
        return m
    }

    static func metal(_ color: UIColor, rough: Float = 0.4) -> SimpleMaterial {
        SimpleMaterial(color: color, roughness: .float(rough), isMetallic: true)
    }

    // MARK: - Crate

    static func makeCrate(_ color: CrateColor, training: Bool = false) -> ModelEntity {
        let s = crateSize
        let body = ModelEntity(
            mesh: mesh("crate") { .generateBox(size: s, cornerRadius: 0.012) },
            materials: [SimpleMaterial(color: color.ui.withAlphaComponent(1), roughness: 0.55, isMetallic: false)]
        )
        body.name = "FoldCrate_\(color)"
        // Dark reinforced edge bands on all four vertical faces.
        let band = mesh("crateBand") { .generateBox(size: [s * 1.04, s * 0.18, s * 1.04], cornerRadius: 0.006) }
        let bandMat = metal(UIColor(white: 0.12, alpha: 1))
        for y: Float in [-0.32, 0.32] {
            let b = ModelEntity(mesh: band, materials: [bandMat])
            b.position = [0, s * y, 0]
            body.addChild(b)
        }
        // Glowing realm sigil on top so it reads from above while hovering.
        let sigil = ModelEntity(
            mesh: mesh("crateSigil") { .generateCylinder(height: 0.002, radius: s * 0.28) },
            materials: [glow(color.ui)]
        )
        sigil.position = [0, s / 2 + 0.001, 0]
        body.addChild(sigil)

        if training {
            let halo = ModelEntity(
                mesh: mesh("trainHalo") { .generateCylinder(height: 0.002, radius: s * 0.9) },
                materials: [glow(.white, 0.35)]
            )
            halo.position = [0, -s / 2 + 0.002, 0]
            halo.components.set(CratePropComponent(motion: .pulse(3)))
            body.addChild(halo)
        }

        body.components.set(CollisionComponent(shapes: [.generateBox(size: [s, s, s])]))
        body.components.set(PhysicsBodyComponent(
            massProperties: .init(mass: 0.4),
            material: .generate(staticFriction: 0.7, dynamicFriction: 0.55, restitution: 0.55),
            mode: .dynamic
        ))
        body.components.set(PhysicsMotionComponent())
        body.components.set(CrateComponent(color: color, isTraining: training))
        return body
    }

    // MARK: - Relay Gate

    static func makeGate(_ color: CrateColor) -> Entity {
        let gate = Entity()
        gate.name = "RelayGate_\(color)"
        gate.position = color.gatePosition

        let base = ModelEntity(
            mesh: mesh("gateBase") { .generateCylinder(height: 0.012, radius: gateRadius * 1.25) },
            materials: [metal(UIColor(white: 0.1, alpha: 1), rough: 0.3)]
        )
        base.position.y = 0.006
        gate.addChild(base)

        let ring = ModelEntity(
            mesh: mesh("gateRing") { .generateCylinder(height: 0.004, radius: gateRadius * 1.12) },
            materials: [glow(color.ui)]
        )
        ring.position.y = 0.013
        gate.addChild(ring)

        let inner = ModelEntity(
            mesh: mesh("gateInner") { .generateCylinder(height: 0.005, radius: gateRadius) },
            materials: [metal(UIColor(white: 0.16, alpha: 1), rough: 0.25)]
        )
        inner.position.y = 0.015
        gate.addChild(inner)

        // Soft landing beam so the target reads from across the room.
        let beam = ModelEntity(
            mesh: mesh("gateBeam") { .generateCylinder(height: 0.9, radius: gateRadius * 0.95) },
            materials: [glow(color.ui, 0.08)]
        )
        beam.position.y = 0.46
        beam.components.set(CratePropComponent(motion: .pulse(1.6)))
        gate.addChild(beam)

        let label = makeText(color.realm.uppercased(), size: 0.03, color: color.ui)
        label.position = [0, 0.02, gateRadius * 1.45]
        label.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        gate.addChild(label)

        // Solid landing surface so crates stack on the gate.
        let pad = Entity()
        pad.position.y = 0.01
        pad.components.set(CollisionComponent(shapes: [.generateBox(size: [gateRadius * 2.4, 0.02, gateRadius * 2.4])]))
        pad.components.set(PhysicsBodyComponent(massProperties: .default,
                                                 material: .generate(staticFriction: 0.9, dynamicFriction: 0.8, restitution: 0.05),
                                                 mode: .static))
        gate.addChild(pad)

        gate.components.set(CrateGateComponent(color: color))
        return gate
    }

    // MARK: - Claw rig

    /// Rig root follows the drone; child "Cable" scales in Y, "Head" sits at the tip.
    static func makeClawRig() -> Entity {
        let rig = Entity()
        rig.name = "FoldClawRig"

        let cable = ModelEntity(
            mesh: mesh("cable") { .generateBox(size: [0.006, 1, 0.006]) },
            materials: [metal(UIColor(white: 0.75, alpha: 1), rough: 0.2)]
        )
        cable.name = "Cable"
        rig.addChild(cable)

        let head = Entity()
        head.name = "Head"
        let hub = ModelEntity(
            mesh: mesh("clawHub") { .generateBox(size: [0.07, 0.025, 0.07], cornerRadius: 0.008) },
            materials: [metal(UIColor(red: 1, green: 0.78, blue: 0.1, alpha: 1), rough: 0.35)]
        )
        head.addChild(hub)
        let lamp = ModelEntity(
            mesh: mesh("clawLamp") { .generateSphere(radius: 0.008) },
            materials: [glow(.white)]
        )
        lamp.name = "Lamp"
        lamp.position = [0, -0.014, 0]
        head.addChild(lamp)
        let prong = mesh("clawProng") { .generateBox(size: [0.008, 0.05, 0.014], cornerRadius: 0.003) }
        for i in 0..<4 {
            let a = Float(i) * .pi / 2
            let pivot = Entity()
            pivot.name = "Prong\(i)"
            pivot.orientation = simd_quatf(angle: a, axis: [0, 1, 0])
            let p = ModelEntity(mesh: prong, materials: [metal(UIColor(white: 0.2, alpha: 1))])
            p.position = [0.032, -0.03, 0]
            pivot.addChild(p)
            head.addChild(pivot)
        }
        // Downward targeting dot projected on whatever is below.
        let marker = ModelEntity(
            mesh: mesh("clawMarker") { .generateCylinder(height: 0.002, radius: 0.03) },
            materials: [glow(.white, 0.5)]
        )
        marker.name = "Marker"
        rig.addChild(marker)

        rig.addChild(head)
        return rig
    }

    // MARK: - Room dressing

    /// Ceiling rift: dark rim, spinning segment ring, pulsing core.
    static func makeRift() -> Entity {
        let rift = Entity()
        rift.name = "IntakeRift"
        let rim = ModelEntity(
            mesh: mesh("riftRim") { .generateCylinder(height: 0.02, radius: 0.26) },
            materials: [metal(UIColor(white: 0.08, alpha: 1), rough: 0.3)]
        )
        rift.addChild(rim)
        let core = ModelEntity(
            mesh: mesh("riftCore") { .generateCylinder(height: 0.022, radius: 0.19) },
            materials: [glow(UIColor(red: 0.75, green: 0.35, blue: 1, alpha: 1))]
        )
        core.components.set(CratePropComponent(motion: .pulse(2.2)))
        rift.addChild(core)
        let ring = Entity()
        ring.components.set(CratePropComponent(motion: .spin(0.9)))
        let seg = mesh("riftSeg") { .generateBox(size: [0.06, 0.026, 0.02], cornerRadius: 0.004) }
        for i in 0..<10 {
            let a = Float(i) / 10 * 2 * .pi
            let s = ModelEntity(mesh: seg, materials: [glow(i % 2 == 0 ? .white : UIColor(red: 1, green: 0.8, blue: 0.2, alpha: 1))])
            s.position = [cos(a) * 0.225, 0, sin(a) * 0.225]
            s.orientation = simd_quatf(angle: -a, axis: [0, 1, 0])
            ring.addChild(s)
        }
        rift.addChild(ring)
        return rift
    }

    /// Guild dispatch board: mounted flush on a wall, facing along +Z.
    static func makeDispatchBoard() -> Entity {
        let board = Entity()
        board.name = "DispatchBoard"
        let panel = ModelEntity(
            mesh: .generateBox(size: [0.62, 0.34, 0.02], cornerRadius: 0.012),
            materials: [metal(UIColor(white: 0.07, alpha: 1), rough: 0.5)]
        )
        board.addChild(panel)
        // Hazard stripe header.
        for i in 0..<12 {
            let stripe = ModelEntity(
                mesh: mesh("hazard") { .generateBox(size: [0.025, 0.03, 0.004]) },
                materials: [glow(i % 2 == 0 ? UIColor(red: 1, green: 0.8, blue: 0.1, alpha: 1) : UIColor(white: 0.05, alpha: 1))]
            )
            stripe.position = [-0.29 + Float(i) * 0.05, 0.145, 0.012]
            stripe.orientation = simd_quatf(angle: 0.5, axis: [0, 0, 1])
            board.addChild(stripe)
        }
        let title = makeText("SORTATION HUB 9", size: 0.036, color: .white)
        title.position = [0, 0.07, 0.012]
        board.addChild(title)
        let sub = makeText("EMERGENCY INTAKE // SORT BY REALM", size: 0.017, color: UIColor(white: 0.7, alpha: 1))
        sub.position = [0, 0.025, 0.012]
        board.addChild(sub)
        for (i, c) in CrateColor.allCases.enumerated() {
            let x = -0.18 + Float(i) * 0.18
            let lamp = ModelEntity(mesh: mesh("boardLamp") { .generateSphere(radius: 0.016) }, materials: [glow(c.ui)])
            lamp.position = [x, -0.05, 0.014]
            lamp.components.set(CratePropComponent(motion: .blink(1.2 + Float(i) * 0.4)))
            board.addChild(lamp)
            let name = makeText(c.realm.uppercased(), size: 0.014, color: c.ui)
            name.position = [x, -0.1, 0.012]
            board.addChild(name)
        }
        return board
    }

    /// Wall gauge with a sweeping needle.
    static func makeIntegrityGauge() -> Entity {
        let g = Entity()
        g.name = "FoldGauge"
        let face = ModelEntity(
            mesh: .generateCylinder(height: 0.02, radius: 0.11),
            materials: [metal(UIColor(white: 0.1, alpha: 1), rough: 0.4)]
        )
        face.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        g.addChild(face)
        let rim = ModelEntity(mesh: .generateCylinder(height: 0.016, radius: 0.118), materials: [glow(UIColor(red: 0.2, green: 1, blue: 0.55, alpha: 1), 0.6)])
        rim.orientation = face.orientation
        rim.position.z = -0.004
        g.addChild(rim)
        let needlePivot = Entity()
        needlePivot.position.z = 0.013
        needlePivot.components.set(CratePropComponent(motion: .sway(1.4)))
        let needle = ModelEntity(mesh: .generateBox(size: [0.006, 0.085, 0.004]), materials: [glow(UIColor(red: 1, green: 0.3, blue: 0.2, alpha: 1))])
        needle.position.y = 0.04
        needlePivot.addChild(needle)
        g.addChild(needlePivot)
        let label = makeText("FOLD INTEGRITY", size: 0.013, color: .white)
        label.position = [0, -0.07, 0.013]
        g.addChild(label)
        return g
    }

    /// Wall conduit: a pipe run with a pulsing coupler.
    static func makeConduit() -> Entity {
        let c = Entity()
        c.name = "Conduit"
        let pipe = ModelEntity(mesh: .generateBox(size: [0.9, 0.035, 0.035], cornerRadius: 0.016),
                               materials: [metal(UIColor(white: 0.35, alpha: 1), rough: 0.25)])
        c.addChild(pipe)
        for x: Float in [-0.3, 0, 0.3] {
            let coupler = ModelEntity(mesh: mesh("coupler") { .generateBox(size: [0.05, 0.05, 0.05], cornerRadius: 0.01) },
                                      materials: [glow(UIColor(red: 0.75, green: 0.35, blue: 1, alpha: 1))])
            coupler.position.x = x
            coupler.components.set(CratePropComponent(motion: .pulse(2 + x)))
            c.addChild(coupler)
        }
        return c
    }

    // MARK: - Text + score pops

    static func makeText(_ string: String, size: CGFloat, color: UIColor, depth: Float = 0.002) -> ModelEntity {
        let m = MeshResource.generateText(string, extrusionDepth: depth,
                                          font: .systemFont(ofSize: size, weight: .heavy),
                                          containerFrame: .zero, alignment: .center, lineBreakMode: .byClipping)
        let e = ModelEntity(mesh: m, materials: [glow(color)])
        let b = m.bounds
        let holder = ModelEntity()
        e.position = [-b.center.x, -b.center.y, 0]
        holder.addChild(e)
        return holder
    }

    /// Floating billboarded score burst. Scale-in punch, rise, fade.
    static func makeScorePop(points: Int, caption: String?, color: UIColor, at pos: SIMD3<Float>, big: Bool) -> Entity {
        let root = Entity()
        root.position = pos
        root.components.set(BillboardComponent())
        let main = makeText("+\(points)", size: big ? 0.09 : 0.065, color: color, depth: 0.01)
        root.addChild(main)
        if let caption {
            let cap = makeText(caption, size: 0.028, color: .white, depth: 0.004)
            cap.position.y = -0.06
            root.addChild(cap)
        }
        root.scale = .init(repeating: 0.01)
        root.components.set(OpacityComponent(opacity: 1))
        root.components.set(CratePopComponent(life: big ? 1.6 : 1.25, rise: 0.4, baseY: pos.y, peakScale: big ? 1.25 : 1))
        return root
    }

    static func makeTextPop(_ text: String, color: UIColor, at pos: SIMD3<Float>) -> Entity {
        let root = Entity()
        root.position = pos
        root.components.set(BillboardComponent())
        root.addChild(makeText(text, size: 0.05, color: color, depth: 0.008))
        root.scale = .init(repeating: 0.01)
        root.components.set(OpacityComponent(opacity: 1))
        root.components.set(CratePopComponent(life: 1.4, rise: 0.25, baseY: pos.y, peakScale: 1))
        return root
    }

    static func makeBurst(color: UIColor, at pos: SIMD3<Float>, count: Int) -> Entity {
        let e = Entity()
        e.position = pos
        var p = ParticleEmitterComponent()
        p.emitterShape = .sphere
        p.emitterShapeSize = [0.04, 0.04, 0.04]
        p.speed = 0.9
        p.speedVariation = 0.5
        p.mainEmitter.birthRate = 0
        p.burstCount = count
        p.mainEmitter.lifeSpan = 0.9
        p.mainEmitter.size = 0.012
        p.mainEmitter.acceleration = [0, -1.2, 0]
        p.mainEmitter.color = .constant(.single(color))
        p.mainEmitter.blendMode = .additive
        p.isEmitting = false
        p.burst()
        e.components.set(p)
        e.components.set(CratePopComponent(life: 1.6, rise: 0, baseY: pos.y, peakScale: 1))
        return e
    }
}

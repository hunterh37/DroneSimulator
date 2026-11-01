//
//  SafariCritterSystem.swift
//  HelicopterGame
//
//  ECS behavior for Safari: wander/hop/flutter, flee from the drone, pop on hit, confetti.
//

import RealityKit
import UIKit
import simd

struct SafariCritterComponent: Component {
    enum State { case wander, flee, popped }

    var kind: SafariCritterKind
    var area: SafariArea
    var home: SIMD3<Float>
    var target: SIMD3<Float>
    var state: State = .wander
    var phase: Float = .random(in: 0...10)
    var retargetIn: Float = 0
    var heading: Float = 0

    var hitRadius: Float { kind.size * 1.6 + 0.2 }
}

struct SafariConfettiComponent: Component {
    var velocity: SIMD3<Float>
    var spin: SIMD3<Float>
    var life: Float
}

final class SafariCritterSystem: System {
    private static let critterQuery = EntityQuery(where: .has(SafariCritterComponent.self))
    private static let confettiQuery = EntityQuery(where: .has(SafariConfettiComponent.self))

    /// Set by SafariManager while the mode is active.
    @MainActor static weak var drone: Entity?

    private let fleeDistance: Float = 3.5
    private let wanderRadius: Float = 6

    required init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(min(context.deltaTime, 1.0 / 30.0))
        let dronePos = MainActor.assumeIsolated { Self.drone?.position(relativeTo: nil) }

        for entity in context.entities(matching: Self.critterQuery, updatingSystemWhen: .rendering) {
            guard var c = entity.components[SafariCritterComponent.self], c.state != .popped else { continue }
            c.phase += dt
            var pos = entity.position

            if let d = dronePos, simd_distance(SIMD2(d.x, d.z), SIMD2(pos.x, pos.z)) < fleeDistance {
                c.state = .flee
                let away = SIMD2(pos.x - d.x, pos.z - d.z)
                let dir = simd_length(away) > 0.01 ? simd_normalize(away) : SIMD2(1, 0)
                c.target = pos + SIMD3(dir.x, 0, dir.y) * 4
            } else if c.state == .flee {
                c.state = .wander
                c.retargetIn = 0
            }

            c.retargetIn -= dt
            if c.state == .wander && (c.retargetIn <= 0 || simd_distance(pos, c.target) < 0.3) {
                let a = Float.random(in: 0..<(2 * .pi)), r = Float.random(in: 0...wanderRadius)
                c.target = c.home + SIMD3(cos(a) * r, 0, sin(a) * r)
                c.retargetIn = .random(in: 2.5...6)
            }

            // Move on XZ.
            let toTarget = SIMD2(c.target.x - pos.x, c.target.z - pos.z)
            let dist = simd_length(toTarget)
            let speed = c.kind.speed * (c.state == .flee ? 1.8 : 0.6)
            if dist > 0.05 {
                let step = simd_normalize(toTarget) * min(dist, speed * dt)
                pos.x += step.x; pos.z += step.y
                let desired = atan2(step.x, step.y)
                var delta = desired - c.heading
                delta = atan2(sin(delta), cos(delta))
                c.heading += delta * min(1, dt * 8)
            }

            // Keep within island and near home.
            let fromHome = SIMD2(pos.x - c.home.x, pos.z - c.home.z)
            if simd_length(fromHome) > wanderRadius * 1.6 { c.state = .wander; c.target = c.home }

            let ground = SafariWorldBuilder.height(x: pos.x, z: pos.z)
            let body = entity.findEntity(named: "body")
            if c.kind.flies {
                pos.y = ground + 1.6 + sin(c.phase * 1.7) * 0.35
                body?.position.y = sin(c.phase * 9) * 0.02
                let flap = sin(c.phase * (c.kind == .bee ? 60 : 14)) * 0.6
                if let body {
                    for wing in body.children where wing.name == "wing" {
                        wing.orientation = simd_quatf(angle: flap * (wing.position.x > 0 ? 1 : -1), axis: [0, 0, 1])
                    }
                }
            } else {
                // Hop cycle with squash & stretch; slime wobbles instead.
                let hopRate: Float = c.state == .flee ? 7 : 4.5
                let t = c.phase * hopRate
                let hop = abs(sin(t))
                let isMoving = dist > 0.1
                pos.y = ground + (isMoving && c.kind != .slime ? hop * c.kind.size * 1.1 : 0)
                let squash = c.kind == .slime ? 1 + sin(t) * 0.12 : (isMoving ? 1 + (hop - 0.5) * 0.18 : 1 + sin(c.phase * 2) * 0.03)
                body?.scale = [1 / sqrt(squash), squash, 1 / sqrt(squash)]
            }

            entity.position = pos
            entity.orientation = simd_quatf(angle: c.heading, axis: [0, 1, 0])
            entity.components.set(c)
        }

        for bit in context.entities(matching: Self.confettiQuery, updatingSystemWhen: .rendering) {
            guard var cf = bit.components[SafariConfettiComponent.self] else { continue }
            cf.life -= dt
            if cf.life <= 0 { bit.removeFromParent(); continue }
            cf.velocity.y -= 6 * dt
            cf.velocity *= (1 - dt * 1.2)
            bit.position += cf.velocity * dt
            bit.orientation = simd_quatf(angle: simd_length(cf.spin) * dt, axis: simd_normalize(cf.spin)) * bit.orientation
            bit.scale = .init(repeating: min(1, cf.life * 2))
            bit.components.set(cf)
        }
    }

    // MARK: - Hits

    /// Called by the missile system. Returns points awarded (0 if already popped).
    @MainActor
    @discardableResult
    static func pop(_ critter: Entity) -> Int {
        guard var c = critter.components[SafariCritterComponent.self], c.state != .popped else { return 0 }
        c.state = .popped
        critter.components.set(c)
        let pos = critter.position(relativeTo: nil)
        if let parent = critter.parent { burstConfetti(at: pos + [0, c.kind.size, 0], color: c.kind.color, in: parent) }
        critter.removeFromParent()
        SafariManager.shared.critterPopped(kind: c.kind, area: c.area, at: pos)
        return c.kind.points
    }

    @MainActor
    private static func burstConfetti(at pos: SIMD3<Float>, color: UIColor, in parent: Entity) {
        let palette: [UIColor] = [color, .systemPink, .systemYellow, .white, .systemTeal]
        for i in 0..<18 {
            let bit = ModelEntity(mesh: LowPolyMesh.icosphere(radius: 0.035, subdivisions: 0),
                                  materials: [LowPolyMesh.material(palette[i % palette.count], roughness: 0.4, emissive: 0.3)])
            bit.position = pos
            let dir = simd_normalize(SIMD3<Float>(Float.random(in: -1...1), Float.random(in: 0.3...1.4), Float.random(in: -1...1)))
            bit.components.set(SafariConfettiComponent(
                velocity: dir * Float.random(in: 2.5...4.5),
                spin: SIMD3<Float>(Float.random(in: -9...9), Float.random(in: -9...9), Float.random(in: 0.1...9)),
                life: Float.random(in: 0.8...1.3)))
            parent.addChild(bit)
        }
    }
}

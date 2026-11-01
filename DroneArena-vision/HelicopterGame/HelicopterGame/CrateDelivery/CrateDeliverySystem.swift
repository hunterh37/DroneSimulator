//
//  CrateDeliverySystem.swift
//  HelicopterGame
//
//  ECS for Fold Freight: claw rig follow + drop/hook/raise, auto release
//  over Relay Gates, score pop animation, ambient prop motion.
//

import RealityKit
import UIKit
import simd

final class CrateDeliverySystem: System {
    private static let crateQuery = EntityQuery(where: .has(CrateComponent.self))
    private static let clawQuery = EntityQuery(where: .has(CrateClawComponent.self))
    private static let gateQuery = EntityQuery(where: .has(CrateGateComponent.self))
    private static let popQuery = EntityQuery(where: .has(CratePopComponent.self))
    private static let propQuery = EntityQuery(where: .has(CratePropComponent.self))

    @MainActor static weak var drone: Entity?
    @MainActor static weak var worldRoot: Entity?
    /// Set by the control panel button, consumed next frame.
    @MainActor static var pressQueued = false

    required init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(min(context.deltaTime, 1.0 / 30.0))
        MainActor.assumeIsolated {
            updatePops(context, dt)
            updateProps(context, dt)
            guard CrateDeliveryManager.shared.isActive else { return }
            let gates = context.entities(matching: Self.gateQuery, updatingSystemWhen: .rendering).map { $0 }
            for gate in gates {
                guard var g = gate.components[CrateGateComponent.self], g.pulse > 0 else { continue }
                g.pulse = max(0, g.pulse - dt * 2.5)
                gate.scale = .init(repeating: 1 + 0.18 * g.pulse * g.pulse)
                gate.components.set(g)
            }
            for rig in context.entities(matching: Self.clawQuery, updatingSystemWhen: .rendering) {
                updateClaw(rig, context: context, gates: gates, dt: dt)
            }
            for crate in context.entities(matching: Self.crateQuery, updatingSystemWhen: .rendering)
            where crate.position(relativeTo: nil).y < -1.5 {
                CrateDeliveryManager.shared.crateLost(crate)
            }
        }
    }

    // MARK: - Claw

    @MainActor
    private func updateClaw(_ rig: Entity, context: SceneUpdateContext, gates: [Entity], dt: Float) {
        guard var claw = rig.components[CrateClawComponent.self], let drone = Self.drone else { return }
        let target = drone.position(relativeTo: nil) - SIMD3<Float>(0, 0.035, 0)
        let current = rig.position(relativeTo: nil)
        let follow = simd_length(target - current) > 0.5 ? target : simd_mix(current, target, .init(repeating: min(1, dt * 22)))
        rig.setPosition(follow, relativeTo: nil)
        rig.setOrientation(simd_quatf(angle: 0, axis: [0, 1, 0]), relativeTo: nil)

        let manager = CrateDeliveryManager.shared
        let carried = claw.carrying.flatMap { id in rig.findEntity(named: "Head")?.children.first { $0.id == id } }

        if Self.pressQueued {
            Self.pressQueued = false
            if let carried {
                release(carried, from: &claw, onto: nil)
            } else if claw.phase == .idle {
                claw.phase = .lowering
                manager.clawDropped()
            }
        }

        let head = rig.findEntity(named: "Head")
        let half = CrateWorldBuilder.crateSize / 2

        switch claw.phase {
        case .lowering:
            claw.reach += CrateClawComponent.lowerSpeed * dt
            claw.grip = max(0, claw.grip - dt * 6)
            let tipY = follow.y - claw.reach - 0.04
            var hooked: Entity?
            for crate in context.entities(matching: Self.crateQuery, updatingSystemWhen: .rendering) {
                guard let c = crate.components[CrateComponent.self], c.state != .carried else { continue }
                let p = crate.position(relativeTo: nil)
                let dxz = simd_distance(SIMD2(p.x, p.z), SIMD2(follow.x, follow.z))
                if dxz < CrateClawComponent.grabRadius && tipY <= p.y + half + 0.015 && tipY > p.y - half {
                    hooked = crate
                    break
                }
            }
            if let hooked, let head {
                grab(hooked, head: head, claw: &claw)
            } else if tipY <= 0.01 || claw.reach >= CrateClawComponent.maxReach {
                claw.phase = .raising
                manager.clawWhiffed()
            }
        case .raising:
            claw.reach -= CrateClawComponent.raiseSpeed * dt
            if claw.reach <= CrateClawComponent.rest {
                claw.reach = CrateClawComponent.rest
                claw.phase = .idle
            }
        case .idle:
            break
        }

        if claw.carrying != nil { claw.grip = min(1, claw.grip + dt * 8) }

        // Auto release over any gate.
        if let carried, claw.phase != .lowering, let crate = carried.components[CrateComponent.self] {
            let tip = follow - SIMD3<Float>(0, claw.reach, 0)
            for gate in gates {
                guard let g = gate.components[CrateGateComponent.self] else { continue }
                let gp = gate.position(relativeTo: nil)
                let dxz = simd_distance(SIMD2(tip.x, tip.z), SIMD2(gp.x, gp.z))
                if dxz < CrateWorldBuilder.gateRadius * 0.85 && tip.y - gp.y < 1.25 {
                    let dropPos = carried.position(relativeTo: nil)
                    let stack = stackHeight(on: gate, context: context, excluding: carried)
                    release(carried, from: &claw, onto: g.color)
                    manager.crateDelivered(carried, color: crate.color, gate: g.color, gateEntity: gate,
                                           stackIndex: stack, at: dropPos)
                    break
                }
            }
        }

        applyRigPose(rig, claw: claw, groundY: 0)
        rig.components.set(claw)
    }

    @MainActor
    private func grab(_ crate: Entity, head: Entity, claw: inout CrateClawComponent) {
        guard var c = crate.components[CrateComponent.self] else { return }
        c.state = .carried
        crate.components.set(c)
        if var body = crate.components[PhysicsBodyComponent.self] {
            body.mode = .kinematic
            crate.components.set(body)
        }
        crate.components.set(PhysicsMotionComponent())
        head.addChild(crate)
        crate.position = [0, -0.03 - CrateWorldBuilder.crateSize / 2, 0]
        crate.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
        claw.carrying = crate.id
        claw.phase = .raising
        CrateDeliveryManager.shared.crateHooked(crate, color: c.color)
    }

    @MainActor
    private func release(_ crate: Entity, from claw: inout CrateClawComponent, onto gate: CrateColor?) {
        guard let root = Self.worldRoot else { return }
        let world = crate.transformMatrix(relativeTo: nil)
        root.addChild(crate)
        crate.setTransformMatrix(world, relativeTo: nil)
        if var body = crate.components[PhysicsBodyComponent.self] {
            body.mode = .dynamic
            crate.components.set(body)
        }
        crate.components.set(PhysicsMotionComponent(linearVelocity: [0, -0.2, 0], angularVelocity: .zero))
        if var c = crate.components[CrateComponent.self] {
            c.state = gate == nil ? .loose : .delivered
            c.settledFor = 0
            crate.components.set(c)
        }
        claw.carrying = nil
        claw.grip = 0
        if claw.phase == .idle { claw.phase = .raising }
    }

    @MainActor
    private func stackHeight(on gate: Entity, context: SceneUpdateContext, excluding: Entity) -> Int {
        let gp = gate.position(relativeTo: nil)
        var count = 0
        for crate in context.entities(matching: Self.crateQuery, updatingSystemWhen: .rendering) where crate != excluding {
            guard crate.components[CrateComponent.self]?.state == .delivered else { continue }
            let p = crate.position(relativeTo: nil)
            if simd_distance(SIMD2(p.x, p.z), SIMD2(gp.x, gp.z)) < CrateWorldBuilder.gateRadius * 1.3 { count += 1 }
        }
        return count
    }

    @MainActor
    private func applyRigPose(_ rig: Entity, claw: CrateClawComponent, groundY: Float) {
        let ext = claw.reach
        if let cable = rig.findEntity(named: "Cable") {
            cable.scale = [1, max(ext, 0.001), 1]
            cable.position = [0, -ext / 2, 0]
        }
        if let head = rig.findEntity(named: "Head") {
            head.position = [0, -ext, 0]
            for i in 0..<4 {
                guard let pivot = head.findEntity(named: "Prong\(i)"), let prong = pivot.children.first else { continue }
                prong.orientation = simd_quatf(angle: 0.55 - claw.grip * 0.7, axis: [0, 0, 1])
            }
        }
        if let marker = rig.findEntity(named: "Marker") {
            let rigY = rig.position(relativeTo: nil).y
            marker.position = [0, groundY + 0.004 - rigY, 0]
            marker.isEnabled = claw.carrying == nil
        }
    }

    // MARK: - Pops + props

    @MainActor
    private func updatePops(_ context: SceneUpdateContext, _ dt: Float) {
        for e in context.entities(matching: Self.popQuery, updatingSystemWhen: .rendering) {
            guard var p = e.components[CratePopComponent.self] else { continue }
            p.age += dt
            if p.age >= p.life { e.removeFromParent(); continue }
            e.components.set(p)
            if e.components.has(ParticleEmitterComponent.self) { continue }
            let t = p.age / p.life
            let s: Float
            if t < 0.16 {
                let k = t / 0.16
                let c1: Float = 2.2
                s = 1 + (c1 + 1) * pow(k - 1, 3) + c1 * pow(k - 1, 2)
            } else {
                s = 1 - max(0, t - 0.75) * 0.8
            }
            e.scale = .init(repeating: max(0.01, s * p.peakScale))
            e.position.y = p.baseY + p.rise * (1 - pow(1 - t, 3))
            e.components.set(OpacityComponent(opacity: t > 0.62 ? max(0, 1 - (t - 0.62) / 0.38) : 1))
        }
    }

    @MainActor
    private func updateProps(_ context: SceneUpdateContext, _ dt: Float) {
        for e in context.entities(matching: Self.propQuery, updatingSystemWhen: .rendering) {
            guard var p = e.components[CratePropComponent.self] else { continue }
            if !p.captured { p.baseScale = e.scale; p.baseOrientation = e.orientation; p.captured = true }
            p.phase += dt
            switch p.motion {
            case .spin(let speed):
                e.orientation = p.baseOrientation * simd_quatf(angle: p.phase * speed, axis: [0, 1, 0])
            case .pulse(let speed):
                e.scale = p.baseScale * (1 + 0.07 * sin(p.phase * speed))
            case .blink(let speed):
                e.components.set(OpacityComponent(opacity: 0.35 + 0.65 * (0.5 + 0.5 * sin(p.phase * speed * 2))))
            case .sway(let speed):
                e.orientation = p.baseOrientation * simd_quatf(angle: sin(p.phase * speed) * 1.1, axis: [0, 0, 1])
            }
            e.components.set(p)
        }
    }
}
